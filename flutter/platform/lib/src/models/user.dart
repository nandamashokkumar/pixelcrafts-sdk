/// User profile from the auth gateway.
/// Returned by `GET /auth/me` and `POST /auth/sync`.
class PCUserProfile {
  final String id;
  final String email;
  final String? name;
  final String? pictureUrl;
  final String? timezone;
  final String? role;
  final String provider;
  final DateTime? createdAt;

  const PCUserProfile({
    required this.id,
    required this.email,
    this.name,
    this.pictureUrl,
    this.timezone,
    this.role,
    required this.provider,
    this.createdAt,
  });

  factory PCUserProfile.fromJson(Map<String, dynamic> json) => PCUserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
        pictureUrl: json['pictureUrl'] as String? ?? json['avatarUrl'] as String?,
        timezone: json['timezone'] as String?,
        role: json['role'] as String?,
        provider: json['provider'] as String? ?? 'firebase',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'pictureUrl': pictureUrl,
        'timezone': timezone,
        'role': role,
        'provider': provider,
        'createdAt': createdAt?.toIso8601String(),
      };
}

/// User settings stored in `user_data`.
/// Returned by `GET /auth/me/settings`.
class PCUserSettings {
  final String? theme; // 'light', 'dark', 'system'
  final String? language;
  final bool? notifications;
  final Map<String, dynamic> extra; // app-specific additional fields

  const PCUserSettings({
    this.theme,
    this.language,
    this.notifications,
    this.extra = const {},
  });

  factory PCUserSettings.fromJson(Map<String, dynamic> json) {
    final knownKeys = {'theme', 'language', 'notifications'};
    final extra = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!knownKeys.contains(entry.key)) {
        extra[entry.key] = entry.value;
      }
    }
    return PCUserSettings(
      theme: json['theme'] as String?,
      language: json['language'] as String?,
      notifications: json['notifications'] as bool?,
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'language': language,
        'notifications': notifications,
        ...extra,
      };
}
