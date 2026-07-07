import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/clip_item.dart';
import 'secure_storage_service.dart';

// ── Response models ────────────────────────────────────────────────────────

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final String userId;
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });
}

class PullResult {
  final List<ClipItem> items;
  final bool hasMore;
  final int nextSince;
  const PullResult(
      {required this.items, required this.hasMore, required this.nextSince});
}

// ── Device-ID interceptor ─────────────────────────────────────────────────

class _DeviceIdInterceptor extends Interceptor {
  final SecureStorageService _storage;
  String? _deviceId;

  _DeviceIdInterceptor(this._storage);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    _deviceId ??= await _storage.getOrCreateDeviceId();
    if (_deviceId != null) {
      options.headers['X-Device-ID'] = _deviceId;
    }
    handler.next(options);
  }
}

// ── Auth interceptor ───────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  bool _refreshing = false;

  _AuthInterceptor(this._storage, this._dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _refreshing) {
      handler.next(err);
      return;
    }

    _refreshing = true;
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        handler.next(err);
        return;
      }

      final res = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {}), // skip auth header for this request
      );

      final newToken = res.data['access_token'] as String;
      await _storage.saveAccessToken(newToken);

      // Retry the original request with the new token.
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken';
      final retry = await _dio.fetch(opts);
      handler.resolve(retry);
    } catch (_) {
      handler.next(err);
    } finally {
      _refreshing = false;
    }
  }
}

// ── ApiClient ──────────────────────────────────────────────────────────────

class ApiClient {
  late final Dio _dio;
  final SecureStorageService _storage;

  ApiClient(this._storage) {
    final baseUrl = kDebugMode
        ? AppConstants.apiBaseUrlDev
        : AppConstants.apiBaseUrlProd;

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_DeviceIdInterceptor(_storage));
    _dio.interceptors.add(_AuthInterceptor(_storage, _dio));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (o) => debugPrint('[API] $o'),
      ));
    }
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthTokens> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final at = res.data['access_token'] as String;
    return AuthTokens(
      accessToken: at,
      refreshToken: res.data['refresh_token'] as String,
      userId: _jwtSub(at),
    );
  }

  // Extracts the `sub` claim from a JWT without a full JWT library.
  static String _jwtSub(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw const FormatException('Malformed JWT');
    var payload = parts[1];
    payload += '=' * ((4 - payload.length % 4) % 4);
    final bytes = base64Url.decode(payload);
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return map['sub'] as String;
  }

  Future<String> register(String email, String password) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
    });
    // Returns { message, user_id }
    return res.data['user_id'] as String;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return {
      'id': res.data['id'] as String,
      'email': res.data['email'] as String,
      'plan': res.data['plan'] as String,
      'file_transfer_addon': res.data['file_transfer_addon'] as bool? ?? false,
    };
  }

  Future<Map<String, dynamic>> purchaseFileTransferAddon() async {
    final res = await _dio.post('/billing/addon/file-transfer');
    return res.data as Map<String, dynamic>;
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  Future<int> pushItems(List<ClipItem> items) async {
    if (items.isEmpty) return 0;
    final res = await _dio.post('/sync/push', data: {
      'items': items.map((c) => _toApiPayload(c)).toList(),
    });
    return res.data['accepted'] as int;
  }

  Future<PullResult> pullItems({int since = 0, int limit = 100}) async {
    final res = await _dio.get('/sync', queryParameters: {
      'since': since,
      'limit': limit,
    });
    final data = res.data as Map<String, dynamic>;
    return PullResult(
      items: (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(ClipItem.fromApi)
          .toList(),
      hasMore: data['has_more'] as bool,
      nextSince: data['next_since'] as int,
    );
  }

  Future<int> deleteItems(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final res = await _dio.post('/sync/delete', data: {'ids': ids});
    return res.data['deleted'] as int;
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String name,
    required String platform,
    String? appVersion,
  }) async {
    final res = await _dio.post('/devices/register', data: {
      'device_id': deviceId,
      'name': name,
      'platform': platform,
      'app_version': ?appVersion,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final res = await _dio.get('/devices');
    return (res.data['devices'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> deleteDevice(String deviceId) async {
    await _dio.delete('/devices/$deviceId');
  }

  // ── Transfer ──────────────────────────────────────────────────────────────

  Future<String> startTransfer({
    required String fileName,
    required int fileSize,
    required String mimeType,
    required String targetDeviceId,
  }) async {
    final res = await _dio.post('/transfer/start', data: {
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'target_device_id': targetDeviceId,
    });
    return res.data['session_id'] as String;
  }

  Future<void> cancelTransfer(String sessionId) async {
    await _dio.delete('/transfer/$sessionId');
  }

  // ── Billing ───────────────────────────────────────────────────────────────

  /// Returns plan list + addons with live prices from the backend.
  Future<Map<String, dynamic>> fetchPlans() async {
    final res = await _dio.get('/billing/plans');
    return res.data as Map<String, dynamic>;
  }

  /// Generate a short-lived browser upgrade URL for the given [tier].
  /// Opens the URL externally so the user can pay via Paystack.
  Future<String> getUpgradeLink(String tier) async {
    final res = await _dio.post('/billing/upgrade-link', data: {'tier': tier});
    return res.data['url'] as String;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _toApiPayload(ClipItem c) => {
        'id': c.id,
        'ciphertext': c.ciphertext,
        'iv': c.iv,
        'content_type': c.contentType.name,
        'tags': c.tags.isEmpty ? null : c.tags,
        'pinned': c.pinned,
        'device_id': c.deviceId,
        'client_created_at': c.clientCreatedAt,
      };
}
