import 'package:clipboard_watcher/clipboard_watcher.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/clip_item.dart';
import 'database_service.dart';
import 'encryption_service.dart';
import 'secure_storage_service.dart';

class ClipboardService with ClipboardListener {
  final DatabaseService _db;
  final SecureStorageService _storage;

  Uint8List? _key;
  String? _deviceId;
  String? _lastText;

  /// Called whenever a new clip is captured and persisted.
  void Function(ClipItem clip)? onNewClip;

  ClipboardService({required this._db, required this._storage});

  bool get isRunning => _key != null;

  Future<void> start(Uint8List key) async {
    _key = key;
    _deviceId ??= await _storage.getOrCreateDeviceId();
    clipboardWatcher.addListener(this);
    await clipboardWatcher.start();
  }

  void updateKey(Uint8List key) => _key = key;

  Future<void> stop() async {
    _key = null;
    clipboardWatcher.removeListener(this);
    try {
      await clipboardWatcher.stop();
    } catch (_) {
      // ignore — already stopped
    }
  }

  @override
  void onClipboardChanged() async {
    final key = _key;
    if (key == null) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || text == _lastText) return;
    _lastText = text;

    final contentType = _detectType(text);
    final encrypted = EncryptionService.encrypt(key, text);

    final clip = ClipItem(
      id: const Uuid().v4(),
      ciphertext: encrypted.ciphertext,
      iv: encrypted.iv,
      contentType: contentType,
      clientCreatedAt: DateTime.now().millisecondsSinceEpoch,
      deviceId: _deviceId,
      plaintext: text,
    );

    await _db.insertClip(clip);
    onNewClip?.call(clip);
  }

  static ContentType _detectType(String text) {
    final t = text.trimLeft().toLowerCase();
    if (t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('ftp://')) {
      return ContentType.url;
    }
    return ContentType.text;
  }
}
