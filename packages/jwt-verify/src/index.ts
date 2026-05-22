import { jwtVerify, createRemoteJWKSet, type JWTPayload } from "jose";

export interface PlatformPrincipal {
  /** Platform user ID (from JWT `sub`) */
  platformUserId: string;
  /** App identifier (from JWT `app_id`) */
  appId: string;
  /** Active entitlements (from JWT `entitlements`) */
  entitlements: string[];
  /** User email (from JWT `email`) */
  email?: string;
  /** Upstream provider UID (from JWT `provider_uid`) */
  providerUid?: string;
}

export interface VerifyOptions {
  /** Raw JWT string (without "Bearer " prefix) */
  token: string;
  /** JWKS endpoint URL, e.g. https://auth.pixelcrafts.app/.well-known/jwks.json */
  jwksUrl: string;
  /** Expected issuer, e.g. https://auth.pixelcrafts.app */
  issuer: string;
  /** If provided, reject tokens whose `app_id` does not match */
  expectedAppId?: string;
  /** Clock tolerance in seconds (default: 60) */
  clockToleranceSeconds?: number;
}

export class JwtVerifyError extends Error {
  constructor(
    message: string,
    public readonly code: "EXPIRED" | "INVALID" | "MISSING_CLAIMS" | "TENANT_MISMATCH"
  ) {
    super(message);
    this.name = "JwtVerifyError";
  }
}

/** Shared JWKS resolver cache — one resolver per URL. */
const jwksCache = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

function getJwks(url: string): ReturnType<typeof createRemoteJWKSet> {
  let jwks = jwksCache.get(url);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(url));
    jwksCache.set(url, jwks);
  }
  return jwks;
}

function isJoseExpired(err: unknown): boolean {
  if (!err || typeof err !== "object") return false;
  return (err as { code?: unknown }).code === "ERR_JWT_EXPIRED";
}

/**
 * Verify a PixelCrafts platform JWT (RS256 via JWKS).
 *
 * Used by both the api-auth gateway (to verify its own tokens on
 * authenticated routes) and brand backends like lavamgam-api-core.
 */
export async function verifyPlatformJwt(
  options: VerifyOptions
): Promise<PlatformPrincipal> {
  const {
    token,
    jwksUrl,
    issuer,
    expectedAppId,
    clockToleranceSeconds = 60,
  } = options;

  let payload: JWTPayload;
  try {
    const result = await jwtVerify(token, getJwks(jwksUrl), {
      issuer,
      algorithms: ["RS256"],
      clockTolerance: clockToleranceSeconds,
    });
    payload = result.payload;
  } catch (err) {
    if (isJoseExpired(err)) {
      throw new JwtVerifyError("Platform JWT expired", "EXPIRED");
    }
    throw new JwtVerifyError("Invalid platform JWT", "INVALID");
  }

  const sub = typeof payload.sub === "string" ? payload.sub : null;
  const appId =
    typeof payload.app_id === "string" ? (payload.app_id as string) : null;

  if (!sub || !appId) {
    throw new JwtVerifyError(
      "Platform JWT missing sub or app_id",
      "MISSING_CLAIMS"
    );
  }

  if (expectedAppId && expectedAppId !== appId) {
    throw new JwtVerifyError(
      `Token app_id (${appId}) does not match expected (${expectedAppId})`,
      "TENANT_MISMATCH"
    );
  }

  const entitlements = Array.isArray(payload.entitlements)
    ? (payload.entitlements as unknown[]).filter(
        (e): e is string => typeof e === "string"
      )
    : [];

  return {
    platformUserId: sub,
    appId,
    entitlements,
    email: typeof payload.email === "string" ? payload.email : undefined,
    providerUid:
      typeof payload.provider_uid === "string"
        ? payload.provider_uid
        : undefined,
  };
}
