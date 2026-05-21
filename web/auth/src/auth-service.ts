import type { AuthResult, PCAuthConfig, PlatformUser } from "./types";

/**
 * Resolved per-app config. `configure()` sets this; everything else
 * reads it. Throws on first use if `configure()` wasn't called —
 * loud failure is intentional, silent fallback would mask a bug
 * where the consumer forgot to wire the SDK.
 */
let resolvedConfig: Required<PCAuthConfig> | null = null;

const DEFAULT_GATEWAY = "https://auth.pixelcrafts.app";
const DEFAULT_VERIFY_ROUTE = "/api/auth/verify";

/**
 * Configure the SDK. Call once at module load (e.g. inside your
 * top-level layout or a `_app.tsx` equivalent), before any other
 * SDK call.
 */
export function configure(config: PCAuthConfig): void {
  resolvedConfig = {
    appId: config.appId,
    gatewayUrl: config.gatewayUrl ?? DEFAULT_GATEWAY,
    verifyRoute: config.verifyRoute ?? DEFAULT_VERIFY_ROUTE,
  };
}

export function getConfig(): Required<PCAuthConfig> {
  if (!resolvedConfig) {
    throw new Error(
      "@pixelcrafts/auth: configure() must be called before using the SDK. " +
        "Add `configure({ appId: '<your-app>' })` to your app bootstrap."
    );
  }
  return resolvedConfig;
}

/**
 * Exchange an upstream identity-provider access token for a platform JWT.
 *
 * Provider-agnostic by design — the gateway's per-app `apps.authProvider`
 * row (firebase | supabase | native) decides which verifier runs. From
 * the SDK's perspective `idToken` is just an opaque string passed through.
 *
 *   - Firebase consumers pass `await user.getIdToken()` (a Firebase ID token).
 *   - Supabase consumers pass `session.access_token` (a Supabase JWT).
 *   - Native consumers pass whatever the brand's own login endpoint issues.
 *
 * The exchange runs through the consumer's own Next.js route (default
 * `/api/auth/verify`) which proxies the call to the gateway server-side.
 * This keeps the gateway's `x-app-id` private from the browser and lets
 * the consumer enforce CORS / rate-limits at their own edge.
 */
export async function exchangeToken(idToken: string): Promise<AuthResult> {
  const { verifyRoute } = getConfig();
  const res = await fetch(verifyRoute, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: idToken }),
  });

  if (!res.ok) {
    const error = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(error.error ?? "Authentication failed");
  }

  return res.json() as Promise<AuthResult>;
}

/**
 * Storage keys are namespaced per app so two pixelcrafts apps on the
 * same origin (rare, but possible during migration) don't fight.
 */
function tokenKey(): string {
  return `pc-auth-${getConfig().appId}-token`;
}

function userKey(): string {
  return `pc-auth-${getConfig().appId}-user`;
}

/** True when running in a real browser, not SSR. */
function isBrowser(): boolean {
  return typeof window !== "undefined" && typeof localStorage !== "undefined";
}

export function storeAuth(result: AuthResult): void {
  if (!isBrowser()) return;
  localStorage.setItem(tokenKey(), result.token);
  localStorage.setItem(userKey(), JSON.stringify(result.user));
}

export function getStoredToken(): string | null {
  if (!isBrowser()) return null;
  return localStorage.getItem(tokenKey());
}

export function getStoredUser(): PlatformUser | null {
  if (!isBrowser()) return null;
  const raw = localStorage.getItem(userKey());
  if (!raw) return null;
  try {
    return JSON.parse(raw) as PlatformUser;
  } catch {
    return null;
  }
}

export function clearAuth(): void {
  if (!isBrowser()) return;
  localStorage.removeItem(tokenKey());
  localStorage.removeItem(userKey());
}

export function isAuthenticated(): boolean {
  return getStoredToken() !== null;
}

/**
 * Storage-key predicate used by the cross-tab sync listener in
 * AuthProvider. Exported so consumers writing their own sync logic
 * can recognise SDK-owned keys.
 */
export function isAuthStorageKey(key: string | null): boolean {
  if (!key) return false;
  return key === tokenKey() || key === userKey();
}
