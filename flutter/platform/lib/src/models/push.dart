/// Push notification preferences.
/// Returned by `GET /push/preferences`.
class PCPushPreferences {
  final bool enabled;
  final List<String> channels; // e.g. ['marketing', 'updates', 'reminders']

  const PCPushPreferences({
    required this.enabled,
    required this.channels,
  });

  factory PCPushPreferences.fromJson(Map<String, dynamic> json) =>
      PCPushPreferences(
        enabled: json['enabled'] as bool? ?? true,
        channels: (json['channels'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'channels': channels,
      };
}
