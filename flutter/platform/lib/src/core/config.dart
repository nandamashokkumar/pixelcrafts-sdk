/// SDK configuration. Set once at app startup.
class PixelCraftsConfig {
  PixelCraftsConfig._();

  static String? _appId;
  static String? _apiKey;
  static String? _baseUrl;
  static Future<String?> Function()? _tokenProvider;
  static Future<String?> Function()? _tokenForceRefresher;
  static void Function()? _onSessionExpired;

  /// App identifier sent as X-App-Id header (e.g. 'verbloom').
  static String get appId => _appId!;

  /// API key sent as x-api-key header.
  static String get apiKey => _apiKey!;

  /// Base URL of the PixelCrafts gateway (e.g. 'https://auth.pixelcrafts.app/v1').
  static String get baseUrl => _baseUrl!;

  /// Callback that returns the current platform JWT.
  static Future<String?> Function()? get tokenProvider => _tokenProvider;

  /// Callback that force-refreshes the platform JWT (used on 401 recovery).
  static Future<String?> Function()? get tokenForceRefresher => _tokenForceRefresher;

  /// Called when a 401 persists after token refresh — app should sign out.
  static void Function()? get onSessionExpired => _onSessionExpired;

  /// Initialize the SDK. Call once in main() before any API usage.
  static void init({
    required String appId,
    required String apiKey,
    required String baseUrl,
    required Future<String?> Function() tokenProvider,
    Future<String?> Function()? tokenForceRefresher,
    void Function()? onSessionExpired,
  }) {
    _appId = appId;
    _apiKey = apiKey;
    _baseUrl = baseUrl;
    _tokenProvider = tokenProvider;
    _tokenForceRefresher = tokenForceRefresher;
    _onSessionExpired = onSessionExpired;
  }

  /// Reset config (useful for testing).
  static void reset() {
    _appId = null;
    _apiKey = null;
    _baseUrl = null;
    _tokenProvider = null;
    _tokenForceRefresher = null;
    _onSessionExpired = null;
  }
}
