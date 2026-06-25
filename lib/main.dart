import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop SQLite (required on macOS/Windows — not available on mobile)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Window setup
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

  runApp(const ProviderScope(child: SnapApp()));
}
