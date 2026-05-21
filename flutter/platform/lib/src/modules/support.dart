import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Support module — tickets and messages.
class SupportModule {
  const SupportModule();

  /// Create a new support ticket.
  Future<ApiResult<Map<String, dynamic>>> createTicket({
    required String subject,
    required String message,
    String category = 'general',
  }) => HttpClient.instance.postMap(ApiEndpoints.supportTickets, body: {
    'subject': subject,
    'message': message,
    'category': category,
  });

  /// List user's tickets.
  Future<ApiResult<List<dynamic>>> getTickets({
    String? status,
    int? page,
    int? limit,
  }) => HttpClient.instance.getList(ApiEndpoints.supportTickets, queryParams: {
    if (status != null) 'status': status,
    if (page != null) 'page': page.toString(),
    if (limit != null) 'limit': limit.toString(),
  });

  /// Get single ticket with messages.
  Future<ApiResult<Map<String, dynamic>>> getTicket(String id) =>
      HttpClient.instance.getMap(ApiEndpoints.supportTicketDetail(id));

  /// Add a message to a ticket.
  Future<ApiResult<Map<String, dynamic>>> addMessage(String ticketId, String message) =>
      HttpClient.instance.postMap(ApiEndpoints.supportTicketMessages(ticketId), body: {
        'message': message,
      });

  /// Close a ticket.
  Future<ApiResult<void>> closeTicket(String id) async {
    final response = await HttpClient.instance.execute(
      'PATCH',
      ApiEndpoints.supportTicketClose(id),
    );
    if (response == null) {
      return (success: false, data: null, error: 'Unable to connect.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (success: true, data: null, error: null);
    }
    return (success: false, data: null, error: 'Failed to close ticket');
  }
}
