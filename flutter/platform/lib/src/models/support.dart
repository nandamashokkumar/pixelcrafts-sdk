/// Support ticket from the auth gateway.
/// Returned by `GET /support/tickets`.
class PCSupportTicket {
  final String id;
  final String subject;
  final String? description;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String? category;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? unreadCount;

  const PCSupportTicket({
    required this.id,
    required this.subject,
    this.description,
    required this.status,
    this.category,
    required this.createdAt,
    this.updatedAt,
    this.unreadCount,
  });

  factory PCSupportTicket.fromJson(Map<String, dynamic> json) =>
      PCSupportTicket(
        id: json['id'] as String,
        subject: json['subject'] as String,
        description: json['description'] as String?,
        status: json['status'] as String,
        category: json['category'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        unreadCount: json['unreadCount'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'description': description,
        'status': status,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'unreadCount': unreadCount,
      };
}

/// Support ticket message.
/// Returned by `GET /support/tickets/:id/messages`.
class PCSupportMessage {
  final String id;
  final String ticketId;
  final String senderType; // 'user', 'agent', 'system'
  final String content;
  final DateTime createdAt;
  final List<String>? attachments;

  const PCSupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.content,
    required this.createdAt,
    this.attachments,
  });

  factory PCSupportMessage.fromJson(Map<String, dynamic> json) =>
      PCSupportMessage(
        id: json['id'] as String,
        ticketId: json['ticketId'] as String,
        senderType: json['senderType'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        attachments: (json['attachments'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketId': ticketId,
        'senderType': senderType,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'attachments': attachments,
      };
}
