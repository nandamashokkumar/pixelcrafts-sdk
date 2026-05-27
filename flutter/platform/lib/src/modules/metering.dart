import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Metering module — budget status and usage.
class MeteringModule {
  const MeteringModule();

  Future<ApiResult<Map<String, dynamic>>> getBudget() =>
      HttpClient.instance.getMap(ApiEndpoints.meteringBudget);

  Future<ApiResult<Map<String, dynamic>>> getUsage({String? period}) =>
      HttpClient.instance.getMap(
        ApiEndpoints.meteringUsage,
        queryParams: {if (period != null) 'period': period},
      );
}
