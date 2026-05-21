import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Storage module — file uploads and presigned URLs.
class StorageModule {
  const StorageModule();

  /// Upload an image (JPEG/PNG/WebP, max 5MB).
  Future<ApiResult<Map<String, dynamic>>> uploadImage(
    String filePath, {
    String? folder,
  }) => HttpClient.instance.uploadMultipart(ApiEndpoints.storageUploadImage, filePath, folder: folder);

  /// Upload a general file (max 10MB).
  Future<ApiResult<Map<String, dynamic>>> uploadFile(
    String filePath, {
    String? folder,
  }) => HttpClient.instance.uploadMultipart(ApiEndpoints.storageUpload, filePath, folder: folder);

  /// Get a presigned URL for private file access.
  Future<ApiResult<Map<String, dynamic>>> getPresignedUrl(String key) =>
      HttpClient.instance.getMap(ApiEndpoints.storagePresignedUrl(key));

  /// Delete a file from storage.
  Future<ApiResult<void>> deleteFile(String key) =>
      HttpClient.instance.deleteVoid(ApiEndpoints.storageFile(key));
}
