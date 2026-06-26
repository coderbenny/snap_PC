import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = DatabaseService();
  await db.initialize();

  final prefs = await SharedPreferences.getInstance();

  // Restore session from Keychain / DPAPI if available.
  final storage = SecureStorageService();
  Uint8List? initialKey;
  if (await storage.hasSession()) {
    final keyB64 = await storage.getEncryptionKey();
    if (keyB64 != null) {
      initialKey = EncryptionService.keyFromBase64(keyB64);
    }
  }

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(960, 660),
    minimumSize: Size(680, 480),
    title: 'SNAP',
    center: true,
    backgroundColor: Color(0xFF0A0A0A),
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialRouteProvider.overrideWithValue(initialKey != null ? '/' : '/login'),
        if (initialKey != null)
          encryptionKeyProvider.overrideWith((_) => initialKey!),
      ],
      child: const SnapApp(),
    ),
  );
}
