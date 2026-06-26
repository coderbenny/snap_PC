import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../constants/app_constants.dart';

/// Result of an encryption operation.
class EncryptResult {
  final String ciphertext; // base64-encoded ciphertext + 16-byte GCM tag
  final String iv; // base64-encoded 12-byte nonce

  const EncryptResult({required this.ciphertext, required this.iv});
}

class EncryptionService {
  EncryptionService._();

  static const int _ivLength = 12; // 96-bit nonce
  static const int _tagBits = 128; // 16-byte GCM auth tag
  static const int _keyLength = 32; // AES-256

  // ── Key derivation ─────────────────────────────────────────────────────────

  /// Derives a 256-bit AES-GCM key via PBKDF2-SHA256.
  /// Salt: utf8("${userId}:snap-key-v1") — matches the web client exactly.
  /// NOTE: 600k iterations is intentionally slow. Call [deriveKeyAsync] from UI.
  static Uint8List deriveKey(String password, String userId) {
    final salt = Uint8List.fromList(
        utf8.encode('$userId${AppConstants.keySaltSuffix}'));
    final passwordBytes = Uint8List.fromList(utf8.encode(password));

    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(
        Pbkdf2Parameters(salt, AppConstants.pbkdf2Iterations, _keyLength));
    return pbkdf2.process(passwordBytes);
  }

  /// Runs [deriveKey] in a background isolate so the UI stays responsive.
  /// Uses Isolate.run() with a closure so no custom sendable class is needed.
  static Future<Uint8List> deriveKeyAsync(String password, String userId) =>
      Isolate.run(() => deriveKey(password, userId));

  // ── Encrypt / decrypt ──────────────────────────────────────────────────────

  /// Encrypts UTF-8 [plaintext] with AES-256-GCM using a random 12-byte IV.
  /// Output ciphertext includes the 16-byte GCM authentication tag (appended).
  static EncryptResult encrypt(Uint8List key, String plaintext) {
    final iv = _randomBytes(_ivLength);
    final input = Uint8List.fromList(utf8.encode(plaintext));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)));

    return EncryptResult(
      ciphertext: base64.encode(cipher.process(input)),
      iv: base64.encode(iv),
    );
  }

  /// Decrypts a ciphertext produced by [encrypt].
  /// Throws [InvalidCipherTextException] if the GCM tag fails verification.
  static String decrypt(Uint8List key, String ciphertextB64, String ivB64) {
    final ciphertext = Uint8List.fromList(base64.decode(ciphertextB64));
    final iv = Uint8List.fromList(base64.decode(ivB64));

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false,
          AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)));

    return utf8.decode(cipher.process(ciphertext));
  }

  // ── Serialisation helpers ──────────────────────────────────────────────────

  static String keyToBase64(Uint8List key) => base64.encode(key);
  static Uint8List keyFromBase64(String b64) =>
      Uint8List.fromList(base64.decode(b64));

  // ── Internal ───────────────────────────────────────────────────────────────

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }
}

