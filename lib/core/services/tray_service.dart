import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener, WindowListener {
  void Function()? onSyncNow;
  void Function()? onQuickPaste;

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);

    await trayManager.setIcon(
      Platform.isMacOS
          ? 'assets/icons/tray_icon.png'
          : 'assets/icons/tray_icon.png',
    );

    await _rebuildMenu();
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
  }

  // ── WindowListener — rebuild menu label when window state changes ──────────

  @override
  void onWindowFocus() => _rebuildMenu();

  @override
  void onWindowBlur() => _rebuildMenu();

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'hide' || eventName == 'show') {
      _rebuildMenu();
    }
  }

  // ── Menu ───────────────────────────────────────────────────────────────────

  Future<void> _rebuildMenu() async {
    final visible = await windowManager.isVisible();
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'toggle', label: visible ? 'Hide Snapit' : 'Show Snapit'),
      MenuItem(key: 'quick', label: 'Quick Paste'),
      MenuItem.separator(),
      MenuItem(key: 'sync', label: 'Sync Now'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit Snapit'),
    ]));
  }

  // ── TrayListener ───────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() => _toggleWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'toggle':
        _toggleWindow();
      case 'quick':
        onQuickPaste?.call();
      case 'sync':
        onSyncNow?.call();
      case 'quit':
        windowManager.destroy();
    }
  }

  // ── Window helpers ─────────────────────────────────────────────────────────

  Future<void> _toggleWindow() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
    await _rebuildMenu();
  }

  Future<void> showWindow() async {
    final visible = await windowManager.isVisible();
    if (!visible) {
      await windowManager.show();
      await windowManager.focus();
      await _rebuildMenu();
    }
  }

  static String get modKey => Platform.isMacOS ? '⌘' : 'Ctrl';
}
