/**
 * Authenticated user identity returned by the gateway. Mirrors the
 * Flutter SDK's `PCUser`. Shape is intentionally minimal — any
 * brand-specific profile fields (preferences, subscription state,
 * onboarding flags) belong in a separate `/users/me` call against
 * the brand API, NOT in this SDK.
 */
export interface PlatformUser {
  id: string;
  email: string;
  role: string;
  provider: string;
  displayName?: string;
}

export interface AuthResult {
  user: PlatformUser;
  token: string;
}

export interface PCAuthConfig {
  /**
   * The app's identifier registered with the gateway. Sent as the
   * `x-app-id` header on every exchange. Must match an `apps` row in
   * pcauth_db; operators set this up via pixelcrafts-web-admin.
   */
  appId: string;

  /**
   * Override the gateway URL. Default points at production.
   * Use this for local dev (e.g. `http://localhost:8787`) or
   * staging environments.
   */
  gatewayUrl?: string;

  /**
   * Server-side route the SDK calls on the client to exchange a
   * Firebase ID token for a platform JWT. Defaults to
   * `/api/auth/verify` — wire this up with `createAuthRoute()` from
   * `@pixelcrafts/auth/server`.
   */
  verifyRoute?: string;
}
