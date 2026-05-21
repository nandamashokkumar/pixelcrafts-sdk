import '../core/http_client.dart';
import '../core/api_endpoints.dart';
import '../core/result.dart';

/// Auth module — user sync, profile, settings, account management.
class AuthModule {
  const AuthModule();

  /// Sync authenticated user to backend (called after sign-in).
  Future<ApiResult<Map<String, dynamic>>> syncUser({
    String? name,
    String? pictureUrl,
    String? timezone,
  }) => HttpClient.instance.postMap(ApiEndpoints.authSync, body: {
    if (name != null) 'name': name,
    if (pictureUrl != null) 'pictureUrl': pictureUrl,
    if (timezone != null) 'timezone': timezone,
  });

  /// Get current authenticated user profile.
  Future<ApiResult<Map<String, dynamic>>> getMe() =>
      HttpClient.instance.getMap(ApiEndpoints.authMe);

  /// Logout — clears server session.
  Future<ApiResult<void>> logout() =>
      HttpClient.instance.deleteVoid(ApiEndpoints.authLogout);

  /// Reactivate an account scheduled for deletion.
  Future<ApiResult<Map<String, dynamic>>> reactivate() =>
      HttpClient.instance.postMap(ApiEndpoints.authReactivate);

  /// Get user settings.
  Future<ApiResult<Map<String, dynamic>>> getSettings() =>
      HttpClient.instance.getMap(ApiEndpoints.userSettings);

  /// Update user settings.
  Future<ApiResult<Map<String, dynamic>>> updateSettings(Map<String, dynamic> settings) =>
      HttpClient.instance.putMap(ApiEndpoints.userSettings, body: settings);

  /// Delete user account (soft delete, 30-day grace period).
  Future<ApiResult<void>> deleteAccount() =>
      HttpClient.instance.deleteVoid(ApiEndpoints.userAccount, queryParams: {'confirm': 'true'});

  /// Export all user data (GDPR).
  Future<ApiResult<Map<String, dynamic>>> exportData() =>
      HttpClient.instance.getMap(ApiEndpoints.userExport);
}
