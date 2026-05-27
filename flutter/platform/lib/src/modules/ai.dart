import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// AI module — text completion, model listing, usage, balance.
class AiModule {
  const AiModule();

  Future<ApiResult<Map<String, dynamic>>> complete(Map<String, dynamic> body) =>
      HttpClient.instance.postMap(ApiEndpoints.aiTextCompletion, body: body);

  Future<ApiResult<Map<String, dynamic>>> listModels() =>
      HttpClient.instance.getMap(ApiEndpoints.aiModels);

  Future<ApiResult<Map<String, dynamic>>> getUsage({
    String? period,
    String? from,
    String? to,
  }) =>
      HttpClient.instance.getMap(
        ApiEndpoints.aiUsage,
        queryParams: {
          if (period != null) 'period': period,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        },
      );

  Future<ApiResult<Map<String, dynamic>>> getBalance() =>
      HttpClient.instance.getMap(ApiEndpoints.aiBalance);
}
