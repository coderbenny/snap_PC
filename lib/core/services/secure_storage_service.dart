import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

final secureStorageProvider = Provider<SecureStorageService>((_) => SecureStorageService());

/// All session credentials are stored as a single JSON blob in one Keychain
/// item — one write = one macOS Keychain prompt instead of one per field.
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      synchronizable: false,
      useDataProtectionKeyChain: false,
    ),
    wOptions: WindowsOptions(),
  );

  static const _sessionKey = 'snap_session_v1';
  static const _deviceIdKey = 'snap_device_id';

  // ── Session (single consolidated Keychain item) ────────────────────────────

  Future<Map<String, String>> _readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeSession(Map<String, String> data) =>
      _storage.write(key: _sessionKey, value: jsonEncode(data));

  /// Saves all session credentials atomically — one Keychain write, one prompt.
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String encryptionKey,
  }) =>
      _writeSession({
        AppConstants.kAccessToken: accessToken,
        AppConstants.kRefreshToken: refreshToken,
        AppConstants.kUserId: userId,
        AppConstants.kEncryptionKey: encryptionKey,
      });

  Future<String?> getAccessToken() async =>
      (await _readSession())[AppConstants.kAccessToken];

  Future<String?> getRefreshToken() async =>
      (await _readSession())[AppConstants.kRefreshToken];

  Future<String?> getUserId() async =>
      (await _readSession())[AppConstants.kUserId];

  Future<String?> getEncryptionKey() async =>
      (await _readSession())[AppConstants.kEncryptionKey];

  Future<bool> hasSession() async =>
      (await _readSession()).containsKey(AppConstants.kAccessToken);

  /// Updates a single field in the session without touching the rest.
  Future<void> _updateSessionField(String field, String value) async {
    final session = await _readSession();
    session[field] = value;
    await _writeSession(session);
  }

  Future<void> saveAccessToken(String token) =>
      _updateSessionField(AppConstants.kAccessToken, token);

  Future<void> saveRefreshToken(String token) =>
      _updateSessionField(AppConstants.kRefreshToken, token);

  Future<void> saveUserId(String id) =>
      _updateSessionField(AppConstants.kUserId, id);

  Future<void> saveEncryptionKey(String base64Key) =>
      _updateSessionField(AppConstants.kEncryptionKey, base64Key);

  // ── Device ID (separate item — created once, never cleared on logout) ──────

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.delete(key: _sessionKey);
}
