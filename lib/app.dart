import 'dart:io';

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

// Height of the hidden title bar area where macOS traffic lights live.
const double _kTitleBarHeight = 28.0;

class _SnapAppState extends ConsumerState<SnapApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();

    // Keep background services alive for the full app lifetime.
    ref.read(clipboardServiceProvider);
    ref.read(syncServiceProvider);
    ref.read(planMonitorProvider);
    ref.read(deviceRegistrationServiceProvider);
    ref.read(eventStreamServiceProvider);
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
      builder: (context, child) => _AppFrame(child: child!),
    );
  }
}

/// Wraps every screen with a transparent drag strip at the top so the window
/// can be moved by dragging, and pushes content below the macOS traffic lights.
class _AppFrame extends StatelessWidget {
  final Widget child;
  const _AppFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    // Only macOS uses TitleBarStyle.hidden — Windows has its own title bar.
    if (!Platform.isMacOS) return child;

    return Column(
      children: [
        DragToMoveArea(
          child: Container(
            height: _kTitleBarHeight,
            color: Colors.transparent,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
