import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

final secureStorageProvider = Provider<SecureStorageService>((_) => SecureStorageService());

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(synchronizable: false),
    wOptions: WindowsOptions(),
  );

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: AppConstants.kAccessToken, value: token);

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.kAccessToken);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: AppConstants.kRefreshToken, value: token);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.kRefreshToken);

  Future<void> saveUserId(String id) =>
      _storage.write(key: AppConstants.kUserId, value: id);

  Future<String?> getUserId() =>
      _storage.read(key: AppConstants.kUserId);

  Future<void> saveUserEmail(String email) =>
      _storage.write(key: AppConstants.kUserEmail, value: email);

  Future<String?> getUserEmail() =>
      _storage.read(key: AppConstants.kUserEmail);

  /// Stores the AES key as base64 raw bytes.
  Future<void> saveEncryptionKey(String base64Key) =>
      _storage.write(key: AppConstants.kEncryptionKey, value: base64Key);

  Future<String?> getEncryptionKey() =>
      _storage.read(key: AppConstants.kEncryptionKey);

  Future<bool> hasSession() async {
    final token = await getAccessToken();
    return token != null;
  }

  /// Clears all stored credentials and the encryption key.
  Future<void> clearAll() => _storage.deleteAll();
}
