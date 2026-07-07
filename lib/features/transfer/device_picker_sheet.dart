import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'transfer_state.dart';

class DevicePickerSheet extends ConsumerStatefulWidget {
  final XFile file;
  final int fileSize;

  const DevicePickerSheet({super.key, required this.file, required this.fileSize});

  @override
  ConsumerState<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends ConsumerState<DevicePickerSheet> {
  List<Map<String, dynamic>>? _devices;
  String? _selectedDeviceId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final api = ref.read(apiClientProvider);
      final devices = await api.listDevices();
      final currentDeviceId =
          await ref.read(secureStorageProvider).getOrCreateDeviceId();
      setState(() {
        _devices = devices
            .where((d) => d['id'] != currentDeviceId)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load devices';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_selectedDeviceId == null) return;
    setState(() => _sending = true);

    final selectedDevice = _devices!.firstWhere((d) => d['id'] == _selectedDeviceId);
    final targetName = selectedDevice['name'] as String? ?? 'Other device';
    final history = ref.read(transferHistoryProvider.notifier);

    // Placeholder sessionId until startSend returns the real one.
    String? sessionId;

    try {
      final transfer = ref.read(transferServiceProvider);
      sessionId = await transfer.startSend(
        widget.file,
        _selectedDeviceId!,
        onProgress: (p) {
          if (sessionId != null) {
            history.update(
              sessionId,
              progress: p,
              status: p >= 1.0 ? TransferStatus.completed : null,
            );
          }
        },
        onError: (e) {
          if (sessionId != null) {
            history.update(sessionId,
                status: TransferStatus.failed, error: e);
          }
        },
      );

      history.add(TransferRecord(
        sessionId: sessionId,
        fileName: widget.file.name,
        fileSize: widget.fileSize,
        direction: TransferDirection.sending,
        status: TransferStatus.inProgress,
        progress: 0,
        startedAt: DateTime.now(),
        targetDeviceName: targetName,
      ));

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (sessionId != null) {
        history.update(sessionId, status: TransferStatus.failed, error: e.toString());
      }
      setState(() {
        _error = e.toString();
        _sending = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.send_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Send to device',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.file.name}  •  ${_formatSize(widget.fileSize)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else if (_error != null && _devices == null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error))
          else if (_devices!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No other devices found. Sign in on another device first.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              itemCount: _devices!.length,
              separatorBuilder: (_, idx) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final device = _devices![i];
                final id = device['id'] as String;
                final name = device['name'] as String;
                final platform = device['platform'] as String;
                final selected = _selectedDeviceId == id;

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedDeviceId = id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                      ),
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(_platformIcon(platform), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(name,
                                style: theme.textTheme.bodyMedium)),
                        if (selected)
                          Icon(Icons.check_circle,
                              size: 16, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (_error != null && _devices != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _sending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_selectedDeviceId == null || _sending) ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, size: 16),
                label: Text(_sending ? 'Sending…' : 'Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'macos':
        return Icons.laptop_mac;
      case 'windows':
        return Icons.laptop_windows;
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      default:
        return Icons.devices;
    }
  }
}
