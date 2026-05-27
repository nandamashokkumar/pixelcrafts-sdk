import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Context module — memory recall, store, list, delete, messages.
class ContextModule {
  const ContextModule();

  Future<ApiResult<Map<String, dynamic>>> recall(Map<String, dynamic> body) =>
      HttpClient.instance.postMap(ApiEndpoints.contextRecall, body: body);

  Future<ApiResult<Map<String, dynamic>>> store(Map<String, dynamic> body) =>
      HttpClient.instance.postMap(ApiEndpoints.contextStore, body: body);

  Future<ApiResult<List<dynamic>>> listMemories({
    required String userId,
    String? projectId,
  }) =>
      HttpClient.instance.getRawList(
        ApiEndpoints.contextMemories,
        queryParams: {
          'userId': userId,
          if (projectId != null) 'projectId': projectId,
        },
      );

  Future<ApiResult<void>> deleteMemory(String id, {required String userId}) =>
      HttpClient.instance.deleteVoid(
        ApiEndpoints.contextMemoryDetail(id),
        queryParams: {'userId': userId},
      );

  Future<ApiResult<List<dynamic>>> getMessages({
    required String conversationId,
    String? limit,
  }) =>
      HttpClient.instance.getRawList(
        ApiEndpoints.contextMessages,
        queryParams: {
          'conversationId': conversationId,
          if (limit != null) 'limit': limit,
        },
      );
}
