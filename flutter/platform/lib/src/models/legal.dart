/// Legal document from the auth gateway.
/// Returned by `GET /legal/documents` and `GET /legal/documents/:type`.
class PCLegalDocument {
  final String type;
  final String title;
  final String content;
  final int version;
  final DateTime? updatedAt;
  final bool required;

  const PCLegalDocument({
    required this.type,
    required this.title,
    required this.content,
    required this.version,
    this.updatedAt,
    required this.required,
  });

  factory PCLegalDocument.fromJson(Map<String, dynamic> json) =>
      PCLegalDocument(
        type: json['type'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        version: json['version'] as int,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        required: json['required'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'content': content,
        'version': version,
        'updatedAt': updatedAt?.toIso8601String(),
        'required': required,
      };
}

/// Legal acceptance status for a user.
/// Returned by `GET /legal/acceptance-status`.
class PCLegalAcceptanceStatus {
  final String documentType;
  final int version;
  final DateTime acceptedAt;

  const PCLegalAcceptanceStatus({
    required this.documentType,
    required this.version,
    required this.acceptedAt,
  });

  factory PCLegalAcceptanceStatus.fromJson(Map<String, dynamic> json) =>
      PCLegalAcceptanceStatus(
        documentType: json['documentType'] as String,
        version: json['version'] as int,
        acceptedAt:
            DateTime.parse(json['acceptedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'documentType': documentType,
        'version': version,
        'acceptedAt': acceptedAt.toIso8601String(),
      };
}
