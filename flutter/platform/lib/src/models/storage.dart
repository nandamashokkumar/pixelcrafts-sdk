/// Metadata for a file stored via the platform.
/// Returned by multipart upload endpoints.
class PCStorageFile {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String mimeType;
  final int sizeBytes;
  final DateTime? createdAt;

  const PCStorageFile({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.mimeType,
    required this.sizeBytes,
    this.createdAt,
  });

  factory PCStorageFile.fromJson(Map<String, dynamic> json) => PCStorageFile(
        id: json['id'] as String,
        url: json['url'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
