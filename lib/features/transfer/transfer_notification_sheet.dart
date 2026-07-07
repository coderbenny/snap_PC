import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'transfer_state.dart';


class TransferNotificationSheet extends ConsumerStatefulWidget {
  final IncomingTransfer transfer;

  const TransferNotificationSheet({super.key, required this.transfer});

  @override
  ConsumerState<TransferNotificationSheet> createState() =>
      _TransferNotificationSheetState();
}

class _TransferNotificationSheetState
    extends ConsumerState<TransferNotificationSheet> {
  bool _accepting = false;
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss if the sender cancels while this sheet is open.
    ref.listenManual(incomingTransferProvider, (_, incoming) {
      if (incoming == null && mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final t = widget.transfer;
    final history = ref.read(transferHistoryProvider.notifier);

    history.add(TransferRecord(
      sessionId: t.sessionId,
      fileName: t.fileName,
      fileSize: t.fileSize,
      direction: TransferDirection.receiving,
      status: TransferStatus.inProgress,
      progress: 0,
      startedAt: DateTime.now(),
      senderDeviceName: t.senderDeviceName,
    ));

    try {
      final transfer = ref.read(transferServiceProvider);
      final file = await transfer.startReceive(
        t.sessionId,
        t.fileName,
        t.fileSize,
        onProgress: (p) {
          setState(() => _progress = p);
          history.update(t.sessionId, progress: p);
        },
        onError: (e) {
          history.update(t.sessionId,
              status: TransferStatus.failed, error: e);
          setState(() {
            _error = e;
            _accepting = false;
          });
        },
      );

      if (!mounted) return;
      ref.read(incomingTransferProvider.notifier).clear();

      if (file != null) {
        history.update(t.sessionId,
            status: TransferStatus.completed, progress: 1.0);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.fileName} saved to Downloads'),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      history.update(t.sessionId,
          status: TransferStatus.failed, error: e.toString());
      if (mounted) {
        setState(() {
          _error = 'Transfer failed';
          _accepting = false;
        });
      }
    }
  }

  Future<void> _decline() async {
    final api = ref.read(apiClientProvider);
    try {
      await api.cancelTransfer(widget.transfer.sessionId);
    } catch (_) {}
    ref.read(incomingTransferProvider.notifier).clear();
    if (mounted) Navigator.of(context).pop();
  }

  // Also mark completed sends as done once device_picker pops with success.
  // (receives: handled in _accept above)


  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = widget.transfer;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_outlined, size: 20),
              const SizedBox(width: 10),
              Text(
                'Incoming file',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'From ${t.senderDeviceName}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            '${t.fileName}  •  ${_formatSize(t.fileSize)}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          if (_accepting && _progress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 4),
            Text(
              '${(_progress! * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _accepting ? null : _decline,
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _accepting ? null : _accept,
                icon: _accepting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 16),
                label: Text(_accepting ? 'Receiving…' : 'Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
