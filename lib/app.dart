import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/providers.dart';
import 'router.dart';
import 'shared/theme/app_theme.dart';

class SnapApp extends ConsumerStatefulWidget {
  const SnapApp({super.key});

  @override
  ConsumerState<SnapApp> createState() => _SnapAppState();
}

class _SnapAppState extends ConsumerState<SnapApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();

    // Keep background services alive for the full app lifetime.
    ref.read(clipboardServiceProvider);
    ref.read(syncServiceProvider);
  }

  Future<void> _initTray() async {
    final tray = ref.read(trayServiceProvider);
    tray.onQuickPaste = _showQuickPanel;
    await tray.init();
  }

  Future<void> _showQuickPanel() async {
    // Resize to compact panel, center on screen, show.
    await windowManager.setSize(const Size(360, 480));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    ref.read(routerProvider).go('/quick');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // Hide to tray instead of closing.
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SNAP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
