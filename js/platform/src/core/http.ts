import { getConfig } from "./config.js";
import type { ApiResult } from "./result.js";

export class HttpClient {
  private cachedToken: string | null = null;
  private tokenCachedAt = 0;
  private readonly cacheMs = 55 * 60 * 1000;
  private handlingSessionExpiry = false;

  private resolveBaseUrl(path: string): string {
    const cfg = getConfig();
    const aiPrefixes = ["/jobs/", "/metering/", "/context/", "/agent/", "/tools/", "/queue/", "/observability/"];
    if (aiPrefixes.some((p) => path.startsWith(p))) {
      return cfg.aiBaseUrl ?? cfg.baseUrl;
    }
    return cfg.baseUrl;
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
      const token = await cfg.tokenProvider();
      if (token) {
        this.cachedToken = token;
        this.tokenCachedAt = now;
        h["Authorization"] = `Bearer ${token}`;
      }
    }
    return h;
  }

  clearTokenCache(): void {
    this.cachedToken = null;
    this.tokenCachedAt = 0;
  }

  private async request(
    method: string,
    path: string,
    { query, body }: { query?: Record<string, string>; body?: unknown } = {}
  ): Promise<Response | null> {
    const url = new URL(path, this.resolveBaseUrl(path));
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

  private async handleTokenExpiry(): Promise<boolean> {
    this.clearTokenCache();
    const refresher = getConfig().tokenForceRefresher;
    if (refresher) {
      const token = await refresher();
      if (token) {
        this.cachedToken = token;
        this.tokenCachedAt = Date.now();
        return true;
      }
    }
    this.fireSessionExpired();
    return false;
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
        return res.status >= 500 ? "Server error. Please try again later." : "Something went wrong.";
    }
  }

  // ─── Public typed helpers ─────────────────────────────────────────────────

  async getMap(path: string, query?: Record<string, string>): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("GET", path, { query });
    if (!res) return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok) return { success: false, data: null, error: this.friendlyError(res) };
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    const data = (json.data ?? json) as Record<string, unknown>;
    return { success: true, data, error: null };
  }

  async getList(path: string, query?: Record<string, string>): Promise<ApiResult<unknown[]>> {
    const res = await this.request("GET", path, { query });
    if (!res) return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok) return { success: false, data: null, error: this.friendlyError(res) };
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    const data = Array.isArray(json.data) ? json.data : Array.isArray(json) ? json : [];
    return { success: true, data, error: null };
  }

  async postMap(path: string, body?: unknown): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("POST", path, { body });
    if (!res) return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok) return { success: false, data: null, error: this.friendlyError(res) };
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    const data = (json.data ?? json) as Record<string, unknown>;
    return { success: true, data, error: null };
  }

  async putMap(path: string, body?: unknown): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("PUT", path, { body });
    if (!res) return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok) return { success: false, data: null, error: this.friendlyError(res) };
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    const data = (json.data ?? json) as Record<string, unknown>;
    return { success: true, data, error: null };
  }

  async patchMap(path: string, body?: unknown): Promise<ApiResult<Record<string, unknown>>> {
    const res = await this.request("PATCH", path, { body });
    if (!res) return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok) return { success: false, data: null, error: this.friendlyError(res) };
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    const data = (json.data ?? json) as Record<string, unknown>;
    return { success: true, data, error: null };
  }

  async deleteVoid(path: string, query?: Record<string, string>): Promise<ApiResult<null>> {
    const res = await this.request("DELETE", path, { query });
    if (!res) return { success: false, data: null, error: "Unable to connect." };
    if (!res.ok) return { success: false, data: null, error: this.friendlyError(res) };
    return { success: true, data: null, error: null };
  }

  /** Raw POST for streaming endpoints (e.g. SSE). Returns the Response directly. */
  async postRaw(path: string, body?: unknown): Promise<Response | null> {
    return this.request("POST", path, { body });
  }
}

export const http = new HttpClient();
