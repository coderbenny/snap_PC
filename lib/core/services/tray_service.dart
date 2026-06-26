import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class TrayService with TrayListener {
  bool _visible = true;

  /// Called when the user requests a manual sync from the tray menu.
  void Function()? onSyncNow;

  /// Called when the user selects Quick Paste from the tray menu.
  void Function()? onQuickPaste;

  Future<void> init() async {
    trayManager.addListener(this);

    await trayManager.setIcon(
      Platform.isMacOS
          ? 'assets/icons/tray_icon.png'
          : 'assets/icons/tray_icon.png',
    );

    await _rebuildMenu();
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  // ── Menu ───────────────────────────────────────────────────────────────────

  Future<void> _rebuildMenu() async {
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'toggle', label: _visible ? 'Hide SNAP' : 'Show SNAP'),
      MenuItem(key: 'quick', label: 'Quick Paste'),
      MenuItem.separator(),
      MenuItem(key: 'sync', label: 'Sync Now'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit SNAP'),
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
    if (_visible) {
      await windowManager.hide();
      _visible = false;
    } else {
      await windowManager.show();
      await windowManager.focus();
      _visible = true;
    }
    await _rebuildMenu();
  }

  Future<void> showWindow() async {
    if (!_visible) {
      await windowManager.show();
      await windowManager.focus();
      _visible = true;
      await _rebuildMenu();
    }
  }

  /// Returns platform-appropriate Ctrl/Cmd key label.
  static String get modKey => Platform.isMacOS ? '⌘' : 'Ctrl';
}
