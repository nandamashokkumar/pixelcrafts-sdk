/// SDK configuration. Set once at app startup.
class PixelCraftsConfig {
  PixelCraftsConfig._();

  static String? _appId;
  static String? _apiKey;
  static String? _authBaseUrl;
  static String? _apiBaseUrl;
  static Future<String?> Function()? _tokenProvider;
  static Future<String?> Function()? _tokenForceRefresher;
  static void Function()? _onSessionExpired;

  /// App identifier sent as X-App-Id header (e.g. 'verbloom').
  static String get appId => _appId!;

  /// API key sent as x-api-key header.
  static String get apiKey => _apiKey!;

  /// Base URL for auth and billing endpoints (e.g. 'https://auth.pixelcrafts.app/v1').
  static String get authBaseUrl => _authBaseUrl ?? _apiBaseUrl!;

  /// Base URL for all other endpoints (sync, push, support, user, legal, storage, etc.).
  static String get apiBaseUrl => _apiBaseUrl!;

  /// Callback that returns the current platform JWT.
  static Future<String?> Function()? get tokenProvider => _tokenProvider;

  /// Callback that force-refreshes the platform JWT (used on 401 recovery).
  static Future<String?> Function()? get tokenForceRefresher => _tokenForceRefresher;

  /// Called when a 401 persists after token refresh — app should sign out.
  static void Function()? get onSessionExpired => _onSessionExpired;

  /// Initialize the SDK. Call once in main() before any API usage.
  ///
  /// For single-backend setups, pass [baseUrl] only.
  /// For split auth/api setups, pass [authBaseUrl] and [apiBaseUrl].
  static void init({
    required String appId,
    required String apiKey,
    String? baseUrl,
    String? authBaseUrl,
    String? apiBaseUrl,
    required Future<String?> Function() tokenProvider,
    Future<String?> Function()? tokenForceRefresher,
    void Function()? onSessionExpired,
  }) {
    if (baseUrl == null && (authBaseUrl == null || apiBaseUrl == null)) {
      throw ArgumentError(
        'Either baseUrl OR both authBaseUrl + apiBaseUrl must be provided.',
      );
    }
    _appId = appId;
    _apiKey = apiKey;
    _authBaseUrl = authBaseUrl ?? baseUrl;
    _apiBaseUrl = apiBaseUrl ?? baseUrl;
    _tokenProvider = tokenProvider;
    _tokenForceRefresher = tokenForceRefresher;
    _onSessionExpired = onSessionExpired;
  }

  /// Reset config (useful for testing).
  static void reset() {
    _appId = null;
    _apiKey = null;
    _authBaseUrl = null;
    _apiBaseUrl = null;
    _tokenProvider = null;
    _tokenForceRefresher = null;
    _onSessionExpired = null;
  }
}
