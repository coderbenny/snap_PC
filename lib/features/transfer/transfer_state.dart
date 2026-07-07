import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Models ────────────────────────────────────────────────────────────────

enum TransferDirection { sending, receiving }
enum TransferStatus { inProgress, completed, failed, cancelled }

@immutable
class TransferRecord {
  final String sessionId;
  final String fileName;
  final int fileSize;
  final TransferDirection direction;
  final TransferStatus status;
  final double progress;
  final DateTime startedAt;
  final String? targetDeviceName;
  final String? senderDeviceName;
  final String? error;

  const TransferRecord({
    required this.sessionId,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.status,
    required this.progress,
    required this.startedAt,
    this.targetDeviceName,
    this.senderDeviceName,
    this.error,
  });

  TransferRecord copyWith({
    TransferStatus? status,
    double? progress,
    String? error,
  }) {
    return TransferRecord(
      sessionId: sessionId,
      fileName: fileName,
      fileSize: fileSize,
      direction: direction,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      startedAt: startedAt,
      targetDeviceName: targetDeviceName,
      senderDeviceName: senderDeviceName,
      error: error ?? this.error,
    );
  }
}

@immutable
class IncomingTransfer {
  final String sessionId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final String senderDeviceName;
  final String targetDeviceId;

  const IncomingTransfer({
    required this.sessionId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.senderDeviceName,
    required this.targetDeviceId,
  });
}

// ── Notifiers ─────────────────────────────────────────────────────────────

class TransferHistoryNotifier extends StateNotifier<List<TransferRecord>> {
  TransferHistoryNotifier() : super([]);

  void add(TransferRecord record) {
    state = [record, ...state];
  }

  void update(String sessionId, {TransferStatus? status, double? progress, String? error}) {
    state = [
      for (final r in state)
        if (r.sessionId == sessionId)
          r.copyWith(status: status, progress: progress, error: error)
        else
          r,
    ];
  }
}

class IncomingTransferNotifier extends StateNotifier<IncomingTransfer?> {
  IncomingTransferNotifier() : super(null);

  void show(IncomingTransfer t) => state = t;

  void dismiss(String sessionId) {
    if (state?.sessionId == sessionId) state = null;
  }

  void clear() => state = null;
}

// ── Providers ─────────────────────────────────────────────────────────────

final transferHistoryProvider =
    StateNotifierProvider<TransferHistoryNotifier, List<TransferRecord>>(
  (_) => TransferHistoryNotifier(),
);

final incomingTransferProvider =
    StateNotifierProvider<IncomingTransferNotifier, IncomingTransfer?>(
  (_) => IncomingTransferNotifier(),
);
