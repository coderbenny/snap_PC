import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

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
  bool _dragging = false;

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
    setState(() => _dragging = false);
    if (detail.files.isEmpty) return;

    final file = detail.files.first;
    final size = await file.length();
    if (!mounted) return;

    // Bring the window to front so the bottom sheet is immediately visible
    // even when the user dropped from another app without switching focus first.
    await windowManager.show();
    await windowManager.focus();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => DevicePickerSheet(file: file, fileSize: size),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onFileDrop,
      child: Stack(
        children: [
          widget.child,
          if (_dragging) const _DropOverlay(),
        ],
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: 1,
        duration: const Duration(milliseconds: 150),
        child: Material(
          color: cs.surface.withValues(alpha: 0.93),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  painter: _DashedBorderPainter(color: cs.onSurface.withValues(alpha: 0.25)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 44),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          size: 52,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Drop to send',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick a device on the next screen',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.45),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const radius = Radius.circular(16);
    const dashLen = 6.0;
    const gapLen = 5.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, radius));

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLen : gapLen;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, distance + len),
            paint,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
