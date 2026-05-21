import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Sync module — user data push/pull and key-level CRUD.
class SyncModule {
  const SyncModule();

  /// Get sync status.
  Future<ApiResult<Map<String, dynamic>>> getStatus() =>
      HttpClient.instance.getMap(ApiEndpoints.syncStatus);

  /// Push data (full replace).
  Future<ApiResult<Map<String, dynamic>>> push(Map<String, dynamic> data) =>
      HttpClient.instance.postMap(ApiEndpoints.syncPush, body: data);

  /// Pull data.
  Future<ApiResult<Map<String, dynamic>>> pull() =>
      HttpClient.instance.getMap(ApiEndpoints.syncPull);

  /// Get all stored data keys.
  Future<ApiResult<Map<String, dynamic>>> getAllData() =>
      HttpClient.instance.getMap(ApiEndpoints.syncData);

  /// Get a single data key.
  Future<ApiResult<Map<String, dynamic>>> getDataKey(String key) =>
      HttpClient.instance.getMap(ApiEndpoints.syncDataKey(key));

  /// Update a single data key (full replace).
  Future<ApiResult<Map<String, dynamic>>> putDataKey(String key, Map<String, dynamic> data) =>
      HttpClient.instance.putMap(ApiEndpoints.syncDataKey(key), body: data);

  /// Patch a single data key (delta merge/remove).
  Future<ApiResult<Map<String, dynamic>>> patchDataKey(
    String key, {
    Map<String, dynamic>? merge,
    List<String>? remove,
  }) => HttpClient.instance.patchMap(ApiEndpoints.syncDataKey(key), body: {
    if (merge != null && merge.isNotEmpty) 'merge': merge,
    if (remove != null && remove.isNotEmpty) 'remove': remove,
  });

  /// Delete a single data key.
  Future<ApiResult<void>> deleteDataKey(String key) =>
      HttpClient.instance.deleteVoid(ApiEndpoints.syncDataKey(key));
}
