import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'auth_state.dart';
import 'exceptions.dart';
import 'models/pc_auth_config.dart';
import 'models/pc_user.dart';
import 'storage/secure_token_store.dart';

/// pixelcrafts central auth client.
///
/// One instance per app. Configure once, use everywhere.
///
/// ```dart
/// // app bootstrap
/// PCAuth.configure(const PCAuthConfig(appId: 'fluentpro'));
///
/// // sign in
/// final user = await PCAuth.instance.signInWithEmail('a@b.c', 'pw');
///
/// // attach to your Dio
/// dio.interceptors.add(PCAuth.instance.interceptor);
///
/// // observe state
/// PCAuth.instance.authStateChanges.listen((state) {
///   if (state == PCAuthState.unauthenticated) router.go('/login');
/// });
/// ```
///
/// **Firebase must be initialized before the first SDK call** —
/// `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
/// in `main()`. The SDK does NOT initialize Firebase; that's per-app config.
class PCAuth {
  PCAuth._(this._config, {SecureTokenStore? storage})
      : _storage = storage ?? SecureTokenStore() {
    _bootstrap();
  }

  // ─── Singleton management ─────────────────────────────────────────────

  static PCAuth? _instance;

  /// Initialize the SDK with [config]. Call once during app startup,
  /// before [instance] is accessed.
  static void configure(PCAuthConfig config, {SecureTokenStore? storage}) {
    _instance = PCAuth._(config, storage: storage);
  }

  /// The configured singleton. Throws [StateError] if [configure] was
  /// not called first.
  static PCAuth get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'PCAuth not configured. Call PCAuth.configure(PCAuthConfig(...)) '
        'during app startup, before reading PCAuth.instance.',
      );
    }
    return i;
  }

  /// Reset the singleton — for tests only. Production code should not
  /// call this.
  static void resetForTesting() {
    _instance = null;
  }

  // ─── Instance state ───────────────────────────────────────────────────

  final PCAuthConfig _config;
  final SecureTokenStore _storage;

  String? _currentToken;
  PCUser? _currentUser;
  PCAuthState _currentState = PCAuthState.initial;
  final _stateController = StreamController<PCAuthState>.broadcast();

  /// Called when the SDK detects the session is irrecoverable
  /// (e.g., refresh failed, gateway rejected the Firebase token). Wire
  /// this to your router so the app routes to login. The SDK has
  /// already cleared local state by the time this fires.
  ///
  /// Example:
  /// ```dart
  /// PCAuth.instance.onSessionExpired = () => router.go('/login');
  /// ```
  void Function()? onSessionExpired;

  /// Current platform JWT, or null if signed out. Synchronous; reads
  /// from the in-memory cache populated at sign-in / bootstrap.
  String? get currentToken => _currentToken;

  /// Current user, or null if signed out.
  PCUser? get currentUser => _currentUser;

  /// Current state. Synchronous — for stream form use [authStateChanges].
  PCAuthState get currentState => _currentState;

  /// Broadcast stream of state transitions. Multiple listeners safe.
  /// Emits [PCAuthState.initial] only on the synthetic startup tick
  /// before the storage check resolves.
  Stream<PCAuthState> get authStateChanges => _stateController.stream;

  // ─── Bootstrap ────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    final token = await _storage.getPlatformToken();
    if (token != null && token.isNotEmpty) {
      _currentToken = token;
      _currentUser = await _restoreCachedUser();
      _setState(PCAuthState.authenticated);
    } else {
      _setState(PCAuthState.unauthenticated);
    }
  }

  void _setState(PCAuthState next) {
    if (_currentState == next) return;
    _currentState = next;
    _stateController.add(next);
  }

  // ─── Public sign-in / sign-up API ─────────────────────────────────────

  /// Sign in with email + password. Firebase first, then gateway exchange.
  Future<PCUser> signInWithEmail(String email, String password) async {
    final cred = await fb.FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    return _exchange(cred);
  }

  /// Create an account with email + password. Firebase creates the
  /// account, then we exchange for the platform JWT (the gateway
  /// auto-creates the user row on first sight).
  Future<PCUser> signUpWithEmail(String email, String password) async {
    final cred = await fb.FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password);
    return _exchange(cred);
  }

  /// Sign in with Google via the native Google Sign-In sheet.
  Future<PCUser> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw const PCSignInException('Google sign-in cancelled', cancelled: true);
    }
    final googleAuth = await googleUser.authentication;
    final cred = await fb.FirebaseAuth.instance.signInWithCredential(
      fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ),
    );
    return _exchange(cred);
  }

  /// Sign in with Apple via Sign in with Apple. Required on iOS by App
  /// Store guideline 4.8 when any other social sign-in is offered.
  Future<PCUser> signInWithApple() async {
    final AuthorizationCredentialAppleID appleCred;
    try {
      appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const PCSignInException(
          'Apple sign-in cancelled',
          cancelled: true,
        );
      }
      rethrow;
    }
    final oauth = fb.OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      accessToken: appleCred.authorizationCode,
    );
    final cred = await fb.FirebaseAuth.instance.signInWithCredential(oauth);
    return _exchange(cred);
  }

  /// Sign in with Twitter / X via Firebase's hosted OAuth flow.
  /// Requires the Twitter provider to be enabled in the Firebase console.
  Future<PCUser> signInWithTwitter() async {
    final provider = fb.OAuthProvider('twitter.com')
      ..setCustomParameters({'lang': 'en'});
    final cred =
        await fb.FirebaseAuth.instance.signInWithProvider(provider);
    return _exchange(cred);
  }

  /// Send a password-reset email via Firebase. Returns when the email
  /// has been queued; Firebase handles delivery + the reset-flow link.
  Future<void> sendPasswordResetEmail(String email) async {
    await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Sign out everywhere. Firebase signOut + Google signOut + clear all
  /// SDK storage + flip state to [PCAuthState.unauthenticated]. Always
  /// completes (errors during Firebase signOut are swallowed — the
  /// local state must always clear).
  Future<void> signOut() async {
    try {
      await fb.FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {
      // Local clear must succeed even if Firebase / Google signOut throws.
    }
    await _storage.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefEmail);
    await prefs.remove(_kPrefDisplayName);
    await prefs.remove(_kPrefRole);
    await prefs.remove(_kPrefProvider);
    _currentToken = null;
    _currentUser = null;
    _setState(PCAuthState.unauthenticated);
  }

  /// Internal — called by the interceptor when refresh fails. Clears
  /// local state and fires [onSessionExpired]. Does NOT call Firebase
  /// signOut (the FB session may still be valid; the gateway just
  /// rejected our exchange).
  Future<void> notifySessionExpired() async {
    await _storage.clearAll();
    _currentToken = null;
    _currentUser = null;
    _setState(PCAuthState.unauthenticated);
    onSessionExpired?.call();
  }

  // ─── The gateway exchange ─────────────────────────────────────────────

  Future<PCUser> _exchange(fb.UserCredential credential) async {
    final firebaseToken = await credential.user?.getIdToken();
    if (firebaseToken == null) {
      throw const PCSignInException('Failed to get Firebase ID token');
    }
    return _exchangeFirebaseTokenInternal(
      firebaseToken,
      displayName: credential.user?.displayName,
      photoUrl: credential.user?.photoURL,
    );
  }

  /// Exchange a Firebase ID token for a platform JWT, without going
  /// through the SDK's built-in sign-in methods.
  ///
  /// **Use case.** Brand apps that already have a `firebase_auth` flow
  /// wired locally (interviewace, mintly's future Phase 5.5b
  /// migration, etc.) can keep their own sign-in screens and call
  /// this method right after Firebase auth succeeds, instead of
  /// rewiring every screen to use [signInWithGoogle] / [signInWithEmail]
  /// etc. on this class.
  ///
  /// The method does the same gateway POST + secure storage + state
  /// update that [signInWithEmail] et al. do internally; it just
  /// starts from an already-fetched Firebase ID token.
  ///
  /// Example:
  /// ```dart
  /// // After your existing firebase_auth sign-in:
  /// final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(...);
  /// final idToken = await cred.user!.getIdToken();
  /// await PCAuth.instance.exchangeFirebaseToken(idToken!);
  ///
  /// // Now PCAuth.instance.currentToken returns the platform JWT,
  /// // wire your API client to read it.
  /// ```
  Future<PCUser> exchangeFirebaseToken(String firebaseIdToken) async {
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    return _exchangeFirebaseTokenInternal(
      firebaseIdToken,
      displayName: fbUser?.displayName,
      photoUrl: fbUser?.photoURL,
    );
  }

  Future<PCUser> _exchangeFirebaseTokenInternal(
    String firebaseToken, {
    String? displayName,
    String? photoUrl,
  }) async {
    // Gateway-targeted Dio. Distinct from the consumer's API client —
    // different base URL, different auth shape (x-app-id, no Bearer
    // because the gateway is what mints the Bearer).
    final dio = Dio(
      BaseOptions(
        baseUrl: _config.gatewayUrl,
        headers: {
          'Content-Type': 'application/json',
          'x-app-id': _config.appId,
        },
      ),
    );

    final response = await dio.post(
      '/auth/token',
      data: {'idToken': firebaseToken},
    );

    final data = response.data as Map<String, dynamic>;
    final platformToken = data['accessJwt'] as String;
    final gatewayUser = data['user'] as Map<String, dynamic>;

    // Gateway response is intentionally minimal — {id, email}. Enrich
    // with Firebase profile fields (displayName, photoUrl) + the JWT
    // entitlements claim (role).
    final user = PCUser(
      id: gatewayUser['id'] as String,
      email: gatewayUser['email'] as String,
      role: _roleFromJwt(platformToken),
      provider: 'firebase',
      displayName: displayName,
      photoUrl: photoUrl,
    );

    await _storage.setPlatformToken(platformToken);
    await _storage.setFirebaseToken(firebaseToken);
    await _storage.setUserId(user.id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefEmail, user.email);
    await prefs.setString(_kPrefDisplayName, user.displayName ?? '');
    await prefs.setString(_kPrefRole, user.role ?? '');
    await prefs.setString(_kPrefProvider, user.provider ?? '');

    _currentToken = platformToken;
    _currentUser = user;
    _setState(PCAuthState.authenticated);

    return user;
  }

  // ─── Token refresh — called by the interceptor on a 401 ───────────────

  /// Refresh the platform JWT using the cached Firebase user. The Dio
  /// interceptor calls this on a 401; consumers typically don't call
  /// it directly.
  ///
  /// Returns the new token on success, or null if the Firebase session
  /// is also gone (in which case the caller should treat as session-
  /// expired and route to login).
  Future<String?> refreshToken() async {
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    if (fbUser == null) return null;

    // Force-refresh the Firebase token, then re-exchange.
    final freshFirebaseToken = await fbUser.getIdToken(true);
    if (freshFirebaseToken == null) return null;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: _config.gatewayUrl,
          headers: {
            'Content-Type': 'application/json',
            'x-app-id': _config.appId,
          },
        ),
      );
      final response = await dio.post(
        '/auth/token',
        data: {'idToken': freshFirebaseToken},
      );
      final data = response.data as Map<String, dynamic>;
      final platformToken = data['accessJwt'] as String;

      await _storage.setPlatformToken(platformToken);
      await _storage.setFirebaseToken(freshFirebaseToken);
      _currentToken = platformToken;
      return platformToken;
    } catch (_) {
      return null;
    }
  }

  // ─── Interceptor ──────────────────────────────────────────────────────

  /// Singleton Dio interceptor consumers add to their own API client.
  /// Reads from [currentToken] on every request; calls [refreshToken]
  /// on a 401; calls [notifySessionExpired] if refresh fails.
  ///
  /// Construct your API client like:
  /// ```dart
  /// final api = Dio(BaseOptions(baseUrl: 'https://api.brand.com'))
  ///   ..interceptors.add(PCAuth.instance.interceptor);
  /// ```
  late final Interceptor interceptor = _PCAuthInterceptorImpl(this);

  // ─── Cached-user restore on bootstrap ─────────────────────────────────

  Future<PCUser?> _restoreCachedUser() async {
    final userId = await _storage.getUserId();
    if (userId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_kPrefEmail);
    if (email == null) return null;
    return PCUser(
      id: userId,
      email: email,
      role: prefs.getString(_kPrefRole),
      provider: prefs.getString(_kPrefProvider),
      displayName: prefs.getString(_kPrefDisplayName),
    );
  }

  // ─── Constants for SharedPreferences keys ─────────────────────────────

  static const _kPrefEmail = 'pc_pref_email';
  static const _kPrefDisplayName = 'pc_pref_display_name';
  static const _kPrefRole = 'pc_pref_role';
  static const _kPrefProvider = 'pc_pref_provider';

  // ─── Helpers ──────────────────────────────────────────────────────────

  /// Decode the platform JWT's entitlements claim. No signature
  /// verification — we just minted this token; the backend will verify
  /// when we use it. Returns "admin" if "admin" in entitlements, else
  /// "user".
  static String _roleFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'user';
      var payload = parts[1];
      final pad = payload.length % 4;
      if (pad != 0) {
        payload = payload.padRight(payload.length + (4 - pad), '=');
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final entitlements = json['entitlements'];
      if (entitlements is List && entitlements.contains('admin')) {
        return 'admin';
      }
      return 'user';
    } catch (_) {
      return 'user';
    }
  }
}

/// Private implementation of the interceptor — the public wrapper class
/// is in [http/pc_auth_interceptor.dart]; this is the actual instance
/// installed on the API Dio. Splitting them lets the public class hide
/// the back-reference to [PCAuth] from consumers.
class _PCAuthInterceptorImpl extends Interceptor {
  _PCAuthInterceptorImpl(this._auth);

  final PCAuth _auth;

  // Single-flight refresh: only one refresh runs concurrently. Multiple
  // 401s coalesce onto the same Future.
  Future<String?>? _inflightRefresh;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final token = _auth.currentToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
      options.headers['x-app-id'] = _auth._config.appId;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode != 401) {
      return handler.next(err);
    }
    // Already retried once — don't loop.
    if (err.requestOptions.extra['pc_auth_retried'] == true) {
      await _auth.notifySessionExpired();
      return handler.next(err);
    }
    // Coalesce concurrent refreshes.
    _inflightRefresh ??= _auth.refreshToken().whenComplete(() {
      _inflightRefresh = null;
    });
    final newToken = await _inflightRefresh;
    if (newToken == null) {
      await _auth.notifySessionExpired();
      return handler.next(err);
    }
    // Replay the original request with the new token.
    err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
    err.requestOptions.extra['pc_auth_retried'] = true;
    try {
      final retried = await Dio().fetch<dynamic>(err.requestOptions);
      return handler.resolve(retried);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }
}
