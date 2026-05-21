// Server-only entry. Import from `@pixelcrafts/auth/server` in
// route handlers, never from client components.

export { createAuthRoute } from "./create-auth-route";
export type { CreateAuthRouteConfig } from "./create-auth-route";
