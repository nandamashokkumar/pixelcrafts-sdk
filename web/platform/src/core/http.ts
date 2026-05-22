import { getConfig } from "./config";
import type { ApiResult } from "./result";

export class HttpClient {
  private cachedToken: string | null = null;
  private tokenCachedAt = 0;
  private readonly cacheMs = 55 * 60 * 1000;
  private handlingSessionExpiry = false;

  get baseUrl(): string {
    return getConfig().baseUrl;
  }

  clearTokenCache(): void {
    this.cachedToken = null;
    this.tokenCachedAt = 0;
  }

  async headers(): Promise<Record<string, string>> {
    const cfg = getConfig();
    const h: Record<string, string> = {
      "X-App-Id": cfg.appId,
      "x-api-key": cfg.apiKey,
      "Content-Type": "application/json",
    };
    const now = Date.now();
    if (this.cachedToken && now - this.tokenCachedAt < this.cacheMs) {
      h["Authorization"] = `Bearer ${this.cachedToken}`;
    } else {
      try {
        const token = await cfg.tokenProvider();
        if (token) {
          this.cachedToken = token;
          this.tokenCachedAt = now;
          h["Authorization"] = `Bearer ${token}`;
        }
      } catch {
        // tokenProvider failed — proceed without auth header; the request
        // will likely 401 and trigger the refresh/retry path.
      }
    }
    return h;
  }

  private async request(
    method: string,
    path: string,
    { query, body }: { query?: Record<string, string>; body?: unknown } = {}
  ): Promise<Response | null> {
    const url = new URL(path, this.baseUrl);
    if (query) {
      Object.entries(query).forEach(([k, v]) => url.searchParams.set(k, v));
    }
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const res = await fetch(url.toString(), {
          method,
          headers: await this.headers(),
          body: body ? JSON.stringify(body) : undefined,
          signal: AbortSignal.timeout(20000),
        });
        if (res.status === 401 && attempt === 0) {
          if (await this.handleTokenExpiry()) continue;
          return res;
        }
        if (res.status >= 500 && attempt === 0) {
          await new Promise((r) => setTimeout(r, 500));
          continue;
        }
        return res;
      } catch {
        if (attempt === 0) {
          await new Promise((r) => setTimeout(r, 500));
          continue;
        }
        return null;
      }
    }
    return null;
  }

  /** Public refresh entry-point — apps can call this when their own
   *  fetch() hits 401 and they need a fresh token to retry. */
  async refreshToken(): Promise<string | null> {
    this.clearTokenCache();
    const refresher = getConfig().tokenForceRefresher;
    if (refresher) {
      try {
        const token = await refresher();
        if (token) {
          this.cachedToken = token;
          this.tokenCachedAt = Date.now();
          return token;
        }
      } catch {
        // refresher failed — fall through
      }
    }
    return null;
  }

  private async handleTokenExpiry(): Promise<boolean> {
    const token = await this.refreshToken();
    return token !== null;
  }

  private fireSessionExpired(): void {
    if (this.handlingSessionExpiry) return;
    this.handlingSessionExpiry = true;
    getConfig().onSessionExpired?.();
    setTimeout(() => (this.handlingSessionExpiry = false), 5000);
  }

  private friendlyError(res: Response): string {
    switch (res.status) {
      case 400:
        return "Invalid request.";
      case 401:
        return "Session expired. Please sign in again.";
      case 403:
        return "Permission denied.";
      case 404:
        return "Not found.";
      case 429:
        return "Too many requests. Please wait.";
      default:
        return res.status >= 500
          ? "Server error. Please try again later."
          : "Something went wrong.";
    }
  }

  /** Shared helper: parse JSON body and extract the data payload. */
  private async parseBody(
    res: Response
  ): Promise<{ ok: true; data: unknown } | { ok: false; error: string }> {
    const json = await res.json().catch(() => ({}));
    const data = json && typeof json === "object" && "data" in json
      ? json.data
      : json;
    return { ok: true, data };
  }

  private makeResult<T>(
    res: Response | null,
    extract: (data: unknown) => T | null
  ): ApiResult<T> {
    if (!res)
      return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok)
      return { success: false, data: null, error: this.friendlyError(res) };
    return this.parseBody(res).then((parsed) => {
      if (!parsed.ok) return { success: false, data: null, error: parsed.error };
      const extracted = extract(parsed.data);
      if (extracted === null)
        return { success: false, data: null, error: "Unexpected response format." };
      return { success: true, data: extracted, error: null };
    }) as unknown as ApiResult<T>;
  }

  async getMap(
    path: string,
    query?: Record<string, string>
  ): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("GET", path, { query });
    return this.makeResult(res, (data) =>
      data && typeof data === "object" && !Array.isArray(data)
        ? (data as Record<string, unknown>)
        : null
    );
  }

  async getList(
    path: string,
    query?: Record<string, string>
  ): Promise<ApiResult<unknown[]>> {
    const res = await this.request("GET", path, { query });
    return this.makeResult(res, (data) =>
      Array.isArray(data) ? data : null
    );
  }

  async postMap(
    path: string,
    body?: unknown
  ): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("POST", path, { body });
    return this.makeResult(res, (data) =>
      data && typeof data === "object" && !Array.isArray(data)
        ? (data as Record<string, unknown>)
        : null
    );
  }

  async putMap(
    path: string,
    body?: unknown
  ): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("PUT", path, { body });
    return this.makeResult(res, (data) =>
      data && typeof data === "object" && !Array.isArray(data)
        ? (data as Record<string, unknown>)
        : null
    );
  }

  async patchMap(
    path: string,
    body?: unknown
  ): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("PATCH", path, { body });
    return this.makeResult(res, (data) =>
      data && typeof data === "object" && !Array.isArray(data)
        ? (data as Record<string, unknown>)
        : null
    );
  }

  async deleteVoid(
    path: string,
    query?: Record<string, string>
  ): Promise<ApiResult<null>> {
    const res = await this.request("DELETE", path, { query });
    if (!res)
      return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok)
      return { success: false, data: null, error: this.friendlyError(res) };
    return { success: true, data: null, error: null };
  }
}

export const http = new HttpClient();
