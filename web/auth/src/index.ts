// Client-safe surface. `@pixelcrafts/auth` (this entry) is safe to
// import from client components. Server-only helpers live in
// `@pixelcrafts/auth/server` (./src/server.ts) — that subpath pulls
// in `next/server` and `Buffer` which must not land in client bundles.

export {
  clearAuth,
  configure,
  exchangeToken,
  getStoredToken,
  getStoredUser,
  isAuthenticated,
  storeAuth,
} from "./auth-service";

export { AuthProvider, useAuth } from "./auth-context";

export type { AuthContextValue, AuthProviderProps } from "./auth-context";
export type { AuthResult, PCAuthConfig, PlatformUser } from "./types";
