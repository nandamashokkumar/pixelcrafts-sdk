/**
 * Server-side route factory for the Firebase-ID-token → platform-JWT
 * exchange. The factory is exported from `@pixelcrafts/auth/server`
 * (separate from the client surface so `next/server` and `Buffer`
 * never end up in a client bundle).
 *
 * Typical wiring in a Next.js App Router project:
 *
 * ```ts
 * // app/api/auth/verify/route.ts
 * import { createAuthRoute } from "@pixelcrafts/auth/server";
 *
 * export const { POST } = createAuthRoute({
 *   appId: process.env.PIXELCRAFTS_APP_ID!,
 *   // gatewayUrl defaults to https://auth.pixelcrafts.app
 * });
 * ```
 */
import { NextResponse } from "next/server";

export interface CreateAuthRouteConfig {
  /** Required. Matches an `apps` row in pcauth_db. */
  appId: string;
  /** Optional override for local dev / staging. */
  gatewayUrl?: string;
  /**
   * Optional override for the role-derivation logic. Default reads
   * the JWT `entitlements` claim and returns `"admin"` when present,
   * else `"user"`. Override this to map your own entitlement names.
   */
  deriveRole?: (claims: Record<string, unknown>) => string;
  /**
   * Optional override for the upstream-call timeout. Default 10s.
   */
  timeoutMs?: number;
}

const DEFAULT_GATEWAY = "https://auth.pixelcrafts.app";

interface GatewayResponse {
  accessJwt: string;
  user: { id: string; email: string };
}

function decodeJwtPayload(jwt: string): Record<string, unknown> {
  const parts = jwt.split(".");
  if (parts.length < 2) return {};
  try {
    const payload = parts[1];
    if (!payload) return {};
    const json = Buffer.from(payload, "base64url").toString("utf-8");
    return JSON.parse(json) as Record<string, unknown>;
  } catch {
    return {};
  }
}

function defaultDeriveRole(claims: Record<string, unknown>): string {
  const entitlements = claims.entitlements;
  if (!Array.isArray(entitlements)) return "user";
  if (entitlements.includes("admin")) return "admin";
  return "user";
}

export function createAuthRoute(config: CreateAuthRouteConfig) {
  const gatewayUrl = config.gatewayUrl ?? DEFAULT_GATEWAY;
  const deriveRole = config.deriveRole ?? defaultDeriveRole;
  const timeoutMs = config.timeoutMs ?? 10_000;

  async function POST(request: Request): Promise<Response> {
    try {
      const body = (await request.json()) as { token?: string };

      if (!body.token || typeof body.token !== "string") {
        return NextResponse.json(
          { error: "Missing or invalid token" },
          { status: 400 }
        );
      }

      const res = await fetch(`${gatewayUrl}/auth/token`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-app-id": config.appId,
        },
        body: JSON.stringify({ idToken: body.token }),
        signal: AbortSignal.timeout(timeoutMs),
      });

      if (!res.ok) {
        const errBody = (await res.json().catch(() => ({}))) as {
          error?: string;
          message?: string;
        };
        return NextResponse.json(
          {
            error:
              errBody.error ?? errBody.message ?? "Authentication failed",
          },
          { status: res.status }
        );
      }

      const gateway = (await res.json()) as GatewayResponse;
      const claims = decodeJwtPayload(gateway.accessJwt);
      const role = deriveRole(claims);

      return NextResponse.json({
        token: gateway.accessJwt,
        user: {
          id: gateway.user.id,
          email: gateway.user.email,
          role,
          provider: "firebase",
        },
      });
    } catch {
      return NextResponse.json(
        { error: "Authentication service unavailable" },
        { status: 503 }
      );
    }
  }

  return { POST };
}
