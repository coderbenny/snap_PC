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

const double _kTitleBarHeight = 28.0;

class _SnapAppState extends ConsumerState<SnapApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();

    ref.read(clipboardServiceProvider);
    ref.read(syncServiceProvider);
    ref.read(planMonitorProvider);
    ref.read(deviceRegistrationServiceProvider);
    ref.read(eventStreamServiceProvider);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    final tray = ref.read(trayServiceProvider);
    tray.onQuickPaste = _showQuickPanel;
    await tray.init();
  }

  Future<void> _showQuickPanel() async {
    await windowManager.setSize(const Size(360, 480));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    ref.read(routerProvider).go('/quick');
  }

  @override
  void onWindowClose() async => windowManager.hide();

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Snapit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => _AppFrame(child: child!),
    );
  }
}

/// Adds the macOS transparent title-bar drag strip above every screen.
/// The DropTarget and incoming-transfer listener live in AuthShell (router.dart)
/// so they have a BuildContext that is inside the GoRouter Navigator.
class _AppFrame extends StatelessWidget {
  final Widget child;
  const _AppFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return child;

    return Column(
      children: [
        DragToMoveArea(
          child: Container(height: _kTitleBarHeight, color: Colors.transparent),
        ),
        Expanded(child: child),
      ],
    );
  }
}
