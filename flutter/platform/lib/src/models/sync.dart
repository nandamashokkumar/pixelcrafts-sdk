/// Sync status from the auth gateway.
/// Returned by `GET /sync/status`.
class PCSyncStatus {
  final int lastSyncedAt; // Unix timestamp (seconds)
  final int serverTimestamp; // Unix timestamp (seconds)
  final bool hasPendingChanges;

  const PCSyncStatus({
    required this.lastSyncedAt,
    required this.serverTimestamp,
    required this.hasPendingChanges,
  });

  factory PCSyncStatus.fromJson(Map<String, dynamic> json) => PCSyncStatus(
        lastSyncedAt: json['lastSyncedAt'] as int? ?? 0,
        serverTimestamp: json['serverTimestamp'] as int? ?? 0,
        hasPendingChanges: json['hasPendingChanges'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'lastSyncedAt': lastSyncedAt,
        'serverTimestamp': serverTimestamp,
        'hasPendingChanges': hasPendingChanges,
      };
}
