import 'package:dio/dio.dart';

import '../pc_auth.dart';

/// Public alias for the SDK's Dio interceptor. The actual implementation
/// lives inside [PCAuth] because it needs a back-reference to call
/// [PCAuth.refreshToken] and [PCAuth.notifySessionExpired].
///
/// Use it via [PCAuth.instance.interceptor]:
///
/// ```dart
/// final api = Dio(BaseOptions(baseUrl: 'https://api.brand.com'))
///   ..interceptors.add(PCAuth.instance.interceptor);
/// ```
///
/// What it does:
/// - On every request: injects `Authorization: Bearer <platform JWT>`
///   and `x-app-id: <configured app id>`. No-op if signed out.
/// - On a 401 response: calls [PCAuth.refreshToken] (single-flight —
///   concurrent 401s share one refresh). If refresh succeeds, the
///   original request is replayed transparently with the new token.
///   If refresh fails, [PCAuth.notifySessionExpired] fires and the
///   original error propagates.
typedef PCAuthInterceptor = Interceptor;
