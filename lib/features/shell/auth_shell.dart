import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transfer/device_picker_sheet.dart';
import '../transfer/transfer_notification_sheet.dart';
import '../transfer/transfer_state.dart';

/// Shell that wraps all authenticated routes.
///
/// Placing this inside GoRouter's ShellRoute ensures its [BuildContext] is
/// a descendant of the Navigator, so [showModalBottomSheet] works correctly.
class AuthShell extends ConsumerStatefulWidget {
  final Widget child;
  const AuthShell({super.key, required this.child});

  @override
  ConsumerState<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends ConsumerState<AuthShell> {
  @override
  void initState() {
    super.initState();
    // Listen for incoming transfers and show the notification sheet.
    // Must be done here (inside the Navigator) not in SnapApp.build.
    ref.listenManual<IncomingTransfer?>(incomingTransferProvider, (_, incoming) {
      if (incoming != null && mounted) {
        showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          builder: (_) => TransferNotificationSheet(transfer: incoming),
        );
      }
    });
  }

  Future<void> _onFileDrop(DropDoneDetails detail) async {
    if (detail.files.isEmpty) return;
    final file = detail.files.first;
    final size = await file.length();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => DevicePickerSheet(file: file, fileSize: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: _onFileDrop,
      child: widget.child,
    );
  }
}
