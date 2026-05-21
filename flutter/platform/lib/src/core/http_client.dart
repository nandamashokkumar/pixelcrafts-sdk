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

  bool _isHandlingSessionExpiry = false;
  String? _cachedToken;
  DateTime? _tokenCachedAt;
  static const _tokenCacheDuration = Duration(minutes: 55);

  void clearTokenCache() {
    _cachedToken = null;
    _tokenCachedAt = null;
  }

  // ─── Public request helpers ────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> getMap(
    String path, {
    Map<String, String>? queryParams,
  }) => _requestMap('GET', path, queryParams: queryParams);

  Future<ApiResult<List<dynamic>>> getList(
    String path, {
    Map<String, String>? queryParams,
  }) => _requestList('GET', path, queryParams: queryParams);

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

  // ─── Multipart upload ──────────────────────────────────────────────────────

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
          if (await _handleTokenExpiry()) continue;
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

  Future<ApiResult<List<dynamic>>> _requestList(
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

  Uri _buildUri(String path, {Map<String, String>? queryParams}) {
    return Uri.parse('${PixelCraftsConfig.baseUrl}$path').replace(
      queryParameters: queryParams != null && queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'X-App-Id': PixelCraftsConfig.appId,
      'x-api-key': PixelCraftsConfig.apiKey,
      'Content-Type': 'application/json',
    };

    final tokenProvider = PixelCraftsConfig.tokenProvider;
    if (tokenProvider != null) {
      final now = DateTime.now();
      if (_cachedToken != null &&
          _tokenCachedAt != null &&
          now.difference(_tokenCachedAt!) < _tokenCacheDuration) {
        headers['Authorization'] = 'Bearer $_cachedToken';
      } else {
        final token = await tokenProvider();
        if (token != null) {
          _cachedToken = token;
          _tokenCachedAt = now;
          headers['Authorization'] = 'Bearer $token';
        }
      }
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

        if (response.statusCode == 401 && attempt == 0) {
          if (await _handleTokenExpiry()) continue;
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

  Future<bool> _handleTokenExpiry() async {
    clearTokenCache();
    final forceRefresher = PixelCraftsConfig.tokenForceRefresher;
    if (forceRefresher != null) {
      final newToken = await forceRefresher();
      if (newToken != null) {
        _cachedToken = newToken;
        _tokenCachedAt = DateTime.now();
        return true;
      }
    }
    _fireSessionExpired();
    return false;
  }

  void _fireSessionExpired() {
    if (_isHandlingSessionExpiry) return;
    _isHandlingSessionExpiry = true;
    PixelCraftsConfig.onSessionExpired?.call();
    Future.delayed(const Duration(seconds: 5), () => _isHandlingSessionExpiry = false);
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
}
