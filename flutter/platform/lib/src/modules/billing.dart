import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Billing module — subscription status, plans, entitlements.
class BillingModule {
  const BillingModule();

  /// Get subscription status for current user + app.
  Future<ApiResult<Map<String, dynamic>>> getStatus() =>
      HttpClient.instance.getMap(ApiEndpoints.billingStatus);

  /// Get all entitlements for current user.
  Future<ApiResult<Map<String, dynamic>>> getEntitlements() =>
      HttpClient.instance.getMap(ApiEndpoints.billingEntitlements);

  /// Get available subscription plans.
  Future<ApiResult<Map<String, dynamic>>> getPlans() =>
      HttpClient.instance.getMap(ApiEndpoints.billingPlans);
}
