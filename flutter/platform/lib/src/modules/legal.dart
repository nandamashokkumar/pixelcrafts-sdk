import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Legal module — documents and acceptance tracking.
class LegalModule {
  const LegalModule();

  /// Get all legal documents (public, no auth required).
  Future<ApiResult<List<dynamic>>> getDocuments() =>
      HttpClient.instance.getList(ApiEndpoints.legalDocuments);

  /// Get a single legal document by type (privacy, terms, cookie, refund).
  Future<ApiResult<Map<String, dynamic>>> getDocument(String type) =>
      HttpClient.instance.getMap(ApiEndpoints.legalDocumentByType(type));

  /// Accept a legal document version.
  Future<ApiResult<Map<String, dynamic>>> accept(
    String documentType,
    String version,
  ) => HttpClient.instance.postMap(ApiEndpoints.legalAccept, body: {
    'documentType': documentType,
    'version': version,
  });

  /// Check acceptance status for all documents.
  Future<ApiResult<Map<String, dynamic>>> getAcceptanceStatus() =>
      HttpClient.instance.getMap(ApiEndpoints.legalAcceptanceStatus);
}
