import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for the platform JWT, Firebase ID token, and user
/// id. Wraps [FlutterSecureStorage] with the right per-platform options
/// (Android: encryptedSharedPreferences = true; iOS: keychain accessible
/// after first unlock).
///
/// **Do not** store the platform JWT in [SharedPreferences] — it's the
/// user's session identity. Always keychain / encrypted prefs.
///
/// Exposed via [pixelcrafts_auth.dart] for advanced consumers who need
/// to read/write storage outside of normal sign-in flows (e.g., session
/// migration). Most apps should not call this directly — use
/// [PCAuth.currentToken] etc.
class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  // Key constants. Namespaced with `pc_` to avoid colliding with any
  // legacy auth keys consumers had before migrating to this SDK.
  static const _kPlatformToken = 'pc_platform_token';
  static const _kFirebaseToken = 'pc_firebase_token';
  static const _kUserId = 'pc_user_id';

  Future<String?> getPlatformToken() => _storage.read(key: _kPlatformToken);

  Future<void> setPlatformToken(String? token) async {
    if (token == null) {
      await _storage.delete(key: _kPlatformToken);
    } else {
      await _storage.write(key: _kPlatformToken, value: token);
    }
  }

  Future<String?> getFirebaseToken() => _storage.read(key: _kFirebaseToken);

  Future<void> setFirebaseToken(String? token) async {
    if (token == null) {
      await _storage.delete(key: _kFirebaseToken);
    } else {
      await _storage.write(key: _kFirebaseToken, value: token);
    }
  }

  Future<String?> getUserId() => _storage.read(key: _kUserId);

  Future<void> setUserId(String? userId) async {
    if (userId == null) {
      await _storage.delete(key: _kUserId);
    } else {
      await _storage.write(key: _kUserId, value: userId);
    }
  }

  /// Wipe every key the SDK writes. Called on signOut. Does NOT touch
  /// keys outside the `pc_` namespace — consumer-owned secure storage
  /// is preserved.
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _kPlatformToken),
      _storage.delete(key: _kFirebaseToken),
      _storage.delete(key: _kUserId),
    ]);
  }
}
