import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Push notification module — device registration and preferences.
class PushModule {
  const PushModule();

  /// Register device for push notifications.
  Future<ApiResult<void>> registerDevice({
    required String fcmToken,
    required String platform,
    required String deviceId,
  }) => HttpClient.instance.postMap(ApiEndpoints.pushRegister, body: {
    'fcmToken': fcmToken,
    'platform': platform,
    'deviceId': deviceId,
  }).then((r) => (success: r.success, data: null, error: r.error));

  /// Unregister device from push notifications.
  Future<ApiResult<void>> unregisterDevice(String deviceId) =>
      HttpClient.instance.deleteVoid(ApiEndpoints.pushUnregister, queryParams: {
        'deviceId': deviceId,
      });

  /// Get push notification preferences.
  Future<ApiResult<Map<String, dynamic>>> getPreferences() =>
      HttpClient.instance.getMap(ApiEndpoints.pushPreferences);

  /// Update push notification preferences.
  Future<ApiResult<Map<String, dynamic>>> updatePreferences({
    required bool enabled,
    required bool reminders,
    required bool updates,
    required bool marketing,
  }) => HttpClient.instance.putMap(ApiEndpoints.pushPreferences, body: {
    'enabled': enabled,
    'reminders': reminders,
    'updates': updates,
    'marketing': marketing,
  });
}
