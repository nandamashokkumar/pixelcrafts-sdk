import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Queue module — enqueue, status, list jobs.
class QueueModule {
  const QueueModule();

  Future<ApiResult<Map<String, dynamic>>> enqueue(Map<String, dynamic> body) =>
      HttpClient.instance.postMap(ApiEndpoints.queueEnqueue, body: body);

  Future<ApiResult<Map<String, dynamic>>> getStatus(String id) =>
      HttpClient.instance.getMap(ApiEndpoints.queueStatus(id));

  Future<ApiResult<List<dynamic>>> listJobs({
    String? queueName,
    String? state,
  }) =>
      HttpClient.instance.getRawList(
        ApiEndpoints.queueJobs,
        queryParams: {
          if (queueName != null) 'queueName': queueName,
          if (state != null) 'state': state,
        },
      );
}
