/// Per-app configuration for [PCAuth].
///
/// Every app gets its own instance with its own [appId] — the gateway
/// uses this to resolve the right Firebase project, billing provider,
/// and entitlement schema per tenant.
///
/// [gatewayUrl] defaults to production. Tests + local dev override.
class PCAuthConfig {
  const PCAuthConfig({
    required this.appId,
    this.gatewayUrl = 'https://auth.pixelcrafts.app',
  });

  /// Tenant identifier. Matches the `apps.id` column in pcauth_db.
  /// Examples: 'lavamgam', 'fluentpro', 'verbloom', 'mintly'.
  /// Sent as the `x-app-id` header on every gateway request.
  final String appId;

  /// Auth gateway base URL. Production: `https://auth.pixelcrafts.app`.
  /// Local dev: typically `http://localhost:3000`.
  final String gatewayUrl;
}
