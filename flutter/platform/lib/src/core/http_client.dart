import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'result.dart';

/// Internal HTTP client for the PixelCrafts Platform SDK.
/// Handles auth headers, token caching, retry logic, and error handling.
class HttpClient {
  HttpClient._();
  static final HttpClient instance = HttpClient._();

  final http.Client _client = http.Client();

  String? _cachedToken;
  DateTime? _tokenCachedAt;
  static const _tokenCacheDuration = Duration(minutes: 55);

  /// Deduplicates concurrent token refreshes. All callers wait on the
  /// same in-flight refresh instead of triggering independent ones.
  Completer<String?>? _refreshCompleter;

  void clearTokenCache() {
    _cachedToken = null;
    _tokenCachedAt = null;
  }

  // ─── Generic request helpers ───────────────────────────────────────────────

  /// Generic GET that parses `data` into a typed model.
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParams,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final result = await _requestMap('GET', path, queryParams: queryParams);
    if (!result.success || result.data == null) {
      return (success: false, data: null, error: result.error);
    }
    try {
      return (success: true, data: fromJson(result.data!), error: null);
    } catch (e) {
      _log('Parse error in GET $path: $e');
      return (success: false, data: null, error: 'Parse error');
    }
  }

  /// Generic GET that parses `data` (List) into typed models.
  Future<ApiResult<List<T>>> getList<T>(
    String path, {
    Map<String, String>? queryParams,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final result = await _requestRawList('GET', path, queryParams: queryParams);
    if (!result.success || result.data == null) {
      return (success: false, data: null, error: result.error);
    }
    try {
      final items = result.data!
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
      return (success: true, data: items, error: null);
    } catch (e) {
      _log('Parse error in GET $path: $e');
      return (success: false, data: null, error: 'Parse error');
    }
  }

  /// Generic POST that parses `data` into a typed model.
  Future<ApiResult<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final result = await _requestMap('POST', path, body: body);
    if (!result.success || result.data == null) {
      return (success: false, data: null, error: result.error);
    }
    try {
      return (success: true, data: fromJson(result.data!), error: null);
    } catch (e) {
      _log('Parse error in POST $path: $e');
      return (success: false, data: null, error: 'Parse error');
    }
  }

  /// Generic PUT that parses `data` into a typed model.
  Future<ApiResult<T>> put<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final result = await _requestMap('PUT', path, body: body);
    if (!result.success || result.data == null) {
      return (success: false, data: null, error: result.error);
    }
    try {
      return (success: true, data: fromJson(result.data!), error: null);
    } catch (e) {
      _log('Parse error in PUT $path: $e');
      return (success: false, data: null, error: 'Parse error');
    }
  }

  /// Generic PATCH that parses `data` into a typed model.
  Future<ApiResult<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final result = await _requestMap('PATCH', path, body: body);
    if (!result.success || result.data == null) {
      return (success: false, data: null, error: result.error);
    }
    try {
      return (success: true, data: fromJson(result.data!), error: null);
    } catch (e) {
      _log('Parse error in PATCH $path: $e');
      return (success: false, data: null, error: 'Parse error');
    }
  }

  /// DELETE with no body parsing.
  Future<ApiResult<void>> delete(
    String path, {
    Map<String, String>? queryParams,
  }) => _requestVoid('DELETE', path, queryParams: queryParams);

  // ─── Legacy untyped helpers (for backwards compat during migration) ─────────

  Future<ApiResult<Map<String, dynamic>>> getMap(
    String path, {
    Map<String, String>? queryParams,
  }) => _requestMap('GET', path, queryParams: queryParams);

  Future<ApiResult<List<dynamic>>> getRawList(
    String path, {
    Map<String, String>? queryParams,
  }) => _requestRawList('GET', path, queryParams: queryParams);

  Future<ApiResult<Map<String, dynamic>>> postMap(
    String path, {
    Map<String, dynamic>? body,
  }) => _requestMap('POST', path, body: body);

  Future<ApiResult<Map<String, dynamic>>> putMap(
    String path, {
    Map<String, dynamic>? body,
  }) => _requestMap('PUT', path, body: body);

  Future<ApiResult<Map<String, dynamic>>> patchMap(
    String path, {
    Map<String, dynamic>? body,
  }) => _requestMap('PATCH', path, body: body);

  Future<ApiResult<void>> deleteVoid(
    String path, {
    Map<String, String>? queryParams,
  }) => _requestVoid('DELETE', path, queryParams: queryParams);

  // ─── Raw request (for PATCH without standard body parsing) ─────────────────

  Future<http.Response?> execute(
    String method,
    String path, {
    Map<String, String>? queryParams,
    String? body,
  }) => _execute(method, _buildUri(path, queryParams: queryParams), body: body);

  // ─── Multipart upload (returns untyped map; caller parses) ─────────────────

  Future<ApiResult<Map<String, dynamic>>> uploadMultipart(
    String path,
    String filePath, {
    String? folder,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final uri = _buildUri(path);
        final headers = await _buildHeaders();
        headers.remove('Content-Type');

        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(headers)
          ..files.add(await http.MultipartFile.fromPath('file', filePath));
        if (folder != null) request.fields['folder'] = folder;

        final streamed = await request.send().timeout(const Duration(seconds: 20));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 401 && attempt == 0) {
          clearTokenCache();
          final newToken = await refreshToken();
          if (newToken != null) continue;
          return (success: false, data: null, error: 'Session expired.');
        }
        if (response.statusCode >= 500 && attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final data = decoded['data'] is Map<String, dynamic>
                ? decoded['data'] as Map<String, dynamic>
                : decoded;
            return (success: true, data: data, error: null);
          }
          return (success: false, data: null, error: 'Unexpected response');
        }
        return (success: false, data: null, error: _friendlyError(response));
      } on SocketException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        return (success: false, data: null, error: 'Unable to connect.');
      } on TimeoutException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        return (success: false, data: null, error: 'Request timed out.');
      }
    }
    return (success: false, data: null, error: 'Upload failed after retries.');
  }

  // ─── DNS reachability check ────────────────────────────────────────────────

  /// Returns `true` if the base host is reachable (HEAD /).
  /// Useful before showing offline UI.
  Future<bool> isReachable() async {
    try {
      final uri = Uri.parse(PixelCraftsConfig.apiBaseUrl);
      final response = await _client
          .head(uri)
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  // ─── Internal implementation ───────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> _requestMap(
    String method,
    String path, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = _buildUri(path, queryParams: queryParams);
      final response = await _execute(method, uri, body: body != null ? json.encode(body) : null);
      if (response == null) {
        return (success: false, data: null, error: 'Unable to connect. Check your internet.');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return (success: true, data: <String, dynamic>{}, error: null);
        }
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final data = decoded['data'] is Map<String, dynamic>
              ? decoded['data'] as Map<String, dynamic>
              : decoded;
          return (success: true, data: data, error: null);
        }
        return (success: false, data: null, error: 'Unexpected response type');
      }
      return (success: false, data: null, error: _friendlyError(response));
    } catch (e) {
      return (success: false, data: null, error: e.toString());
    }
  }

  Future<ApiResult<List<dynamic>>> _requestRawList(
    String method,
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = _buildUri(path, queryParams: queryParams);
      final response = await _execute(method, uri);
      if (response == null) {
        return (success: false, data: null, error: 'Unable to connect. Check your internet.');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = json.decode(response.body);
        if (body is Map<String, dynamic> && body['data'] is List) {
          return (success: true, data: body['data'] as List<dynamic>, error: null);
        } else if (body is List) {
          return (success: true, data: body, error: null);
        }
        return (success: true, data: <dynamic>[], error: null);
      }
      return (success: false, data: null, error: _friendlyError(response));
    } catch (e) {
      return (success: false, data: null, error: e.toString());
    }
  }

  Future<ApiResult<void>> _requestVoid(
    String method,
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = _buildUri(path, queryParams: queryParams);
      final response = await _execute(method, uri);
      if (response == null) {
        return (success: false, data: null, error: 'Unable to connect. Check your internet.');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (success: true, data: null, error: null);
      }
      return (success: false, data: null, error: _friendlyError(response));
    } catch (e) {
      return (success: false, data: null, error: e.toString());
    }
  }

  /// Auth, billing, user, push, support, and legal endpoints route to
  /// [PixelCraftsConfig.authBaseUrl]; everything else routes to
  /// [PixelCraftsConfig.apiBaseUrl].
  String _resolveBaseUrl(String path) {
    if (path.startsWith('/auth/') ||
        path.startsWith('/billing/') ||
        path.startsWith('/user/') ||
        path.startsWith('/push/') ||
        path.startsWith('/support/') ||
        path.startsWith('/legal/')) {
      return PixelCraftsConfig.authBaseUrl;
    }
    return PixelCraftsConfig.apiBaseUrl;
  }

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    return Uri.parse('${_resolveBaseUrl(path)}$path').replace(
      queryParameters: queryParams != null && queryParams.isNotEmpty ? queryParams : null,
    );
  }

  /// Read token from cache or tokenProvider.
  Future<String?> _getToken() async {
    final now = DateTime.now();
    if (_cachedToken != null &&
        _tokenCachedAt != null &&
        now.difference(_tokenCachedAt!) < _tokenCacheDuration) {
      return _cachedToken;
    }
    final tokenProvider = PixelCraftsConfig.tokenProvider;
    if (tokenProvider == null) return null;
    try {
      final token = await tokenProvider();
      if (token != null) {
        _cachedToken = token;
        _tokenCachedAt = now;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'X-App-Id': PixelCraftsConfig.appId,
      'x-api-key': PixelCraftsConfig.apiKey,
      'Content-Type': 'application/json',
      if (PixelCraftsConfig.appVersion != null)
        'X-App-Version': PixelCraftsConfig.appVersion!,
      if (PixelCraftsConfig.platform != null)
        'X-Platform': PixelCraftsConfig.platform!,
    };

    final token = await _getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response?> _execute(
    String method,
    Uri uri, {
    String? body,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _buildHeaders();
        _log('$method ${uri.toString()}');
        final http.Response response;
        switch (method) {
          case 'GET':
            response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
          case 'POST':
            response = await _client.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          case 'PUT':
            response = await _client.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          case 'PATCH':
            response = await _client.patch(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
          case 'DELETE':
            response = await _client.delete(uri, headers: headers).timeout(const Duration(seconds: 20));
          default:
            return null;
        }

        _log('  → ${response.statusCode}');
        if (response.statusCode == 401 && attempt == 0) {
          clearTokenCache();
          final newToken = await refreshToken();
          if (newToken != null) continue;
          return response;
        }
        if (response.statusCode >= 500 && attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        return response;
      } on SocketException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        return null;
      } on TimeoutException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Public refresh entry-point — deduplicated. All callers wait on the
  /// same in-flight refresh instead of triggering independent ones.
  /// Returns the new token, or null if refresh failed.
  Future<String?> refreshToken() async {
    // If a refresh is already in-flight, wait for it.
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final result = await _performRefresh();
      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Actual refresh logic — clears cache, calls forceRefresher, updates cache.
  Future<String?> _performRefresh() async {
    clearTokenCache();
    final forceRefresher = PixelCraftsConfig.tokenForceRefresher;
    if (forceRefresher != null) {
      try {
        final newToken = await forceRefresher();
        if (newToken != null) {
          _cachedToken = newToken;
          _tokenCachedAt = DateTime.now();
          return newToken;
        }
      } catch (_) {
        // refresher failed — fall through
      }
    }
    return null;
  }

  String _friendlyError(http.Response response) {
    final apiMsg = _parseApiMessage(response);
    switch (response.statusCode) {
      case 400:
        return apiMsg ?? 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return "You don't have permission for this action.";
      case 404:
        return apiMsg ?? 'Not found.';
      case 409:
        return apiMsg ?? 'Conflict. Please try again.';
      case 422:
        return apiMsg ?? 'Please check your input.';
      case 429:
        return 'Too many requests. Please wait.';
      default:
        if (response.statusCode >= 500) return 'Server error. Please try again later.';
        return apiMsg ?? 'Something went wrong.';
    }
  }

  String? _parseApiMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map) return error['message']?.toString();
        if (body['message'] != null) return body['message']?.toString();
      }
    } catch (_) {}
    return null;
  }

  void _log(String message) {
    if (kDebugMode && PixelCraftsConfig.debugLogging) {
      // ignore: avoid_print
      print('[PixelCraftsPlatform] $message');
    }
  }
}
