import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'transfer_state.dart';

class TransferHistoryScreen extends ConsumerWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(transferHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 24, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => context.go('/'),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Text(
                  'Transfers',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'In-session history — clears when the app restarts.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: records.isEmpty
                ? _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: records.length,
                    separatorBuilder: (_, idx) => const Divider(height: 1, indent: 64),
                    itemBuilder: (context, i) =>
                        _TransferRow(record: records[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No transfers yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Drag a file onto the app window to send it\nto one of your other devices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

// ── Row ────────────────────────────────────────────────────────────────────

class _TransferRow extends StatelessWidget {
  final TransferRecord record;
  const _TransferRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSending = record.direction == TransferDirection.sending;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Direction icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _directionColor(record.status, isSending, theme)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _directionIcon(record.status, isSending),
              size: 18,
              color: _directionColor(record.status, isSending, theme),
            ),
          ),
          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(record),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                if (record.status == TransferStatus.inProgress &&
                    record.progress > 0) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: record.progress,
                      minHeight: 4,
                    ),
                  ),
                ],
                if (record.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Status badge
          _StatusChip(status: record.status, progress: record.progress),
        ],
      ),
    );
  }

  String _subtitle(TransferRecord r) {
    final size = _formatSize(r.fileSize);
    final peer = r.direction == TransferDirection.sending
        ? r.targetDeviceName
        : r.senderDeviceName;
    final timeAgo = _relativeTime(r.startedAt);
    if (peer != null) return '$size · ${r.direction == TransferDirection.sending ? 'To' : 'From'} $peer · $timeAgo';
    return '$size · $timeAgo';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  IconData _directionIcon(TransferStatus status, bool sending) {
    if (status == TransferStatus.failed) return Icons.error_outline;
    if (status == TransferStatus.cancelled) return Icons.cancel_outlined;
    if (status == TransferStatus.completed) return Icons.check_circle_outline;
    return sending ? Icons.upload_outlined : Icons.download_outlined;
  }

  Color _directionColor(TransferStatus status, bool sending, ThemeData theme) {
    return switch (status) {
      TransferStatus.failed => theme.colorScheme.error,
      TransferStatus.cancelled => theme.colorScheme.onSurfaceVariant,
      TransferStatus.completed => Colors.green,
      TransferStatus.inProgress =>
        sending ? theme.colorScheme.primary : Colors.teal,
    };
  }
}

// ── Status chip ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final TransferStatus status;
  final double progress;
  const _StatusChip({required this.status, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (status) {
      TransferStatus.inProgress => SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 3),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      TransferStatus.completed => const Icon(
          Icons.check_circle,
          size: 18,
          color: Colors.green,
        ),
      TransferStatus.failed => Icon(
          Icons.error,
          size: 18,
          color: theme.colorScheme.error,
        ),
      TransferStatus.cancelled => Icon(
          Icons.cancel,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
    };
  }
}
