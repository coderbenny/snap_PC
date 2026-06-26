import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'api_client.dart';
import 'database_service.dart';

enum SyncStatus { idle, syncing, error, upgradeRequired }

class SyncService {
  final ApiClient _api;
  final DatabaseService _db;
  final SharedPreferences _prefs;

  Timer? _timer;
  bool _syncing = false;

  void Function(SyncStatus status)? onStatusChange;
  void Function()? onSyncComplete;

  SyncService({
    required this._api,
    required this._db,
    required this._prefs,
  });

  bool get isSyncing => _syncing;

  Future<void> start() async {
    await syncNow();
    _timer ??= Timer.periodic(AppConstants.syncInterval, (_) => syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    onStatusChange?.call(SyncStatus.syncing);

    try {
      await _push();
      await _pull();
      onStatusChange?.call(SyncStatus.idle);
      onSyncComplete?.call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Free-plan user — sync not available; not an error to display.
        onStatusChange?.call(SyncStatus.upgradeRequired);
      } else {
        onStatusChange?.call(SyncStatus.error);
      }
    } catch (_) {
      onStatusChange?.call(SyncStatus.error);
    } finally {
      _syncing = false;
    }
  }

  // ── Push ───────────────────────────────────────────────────────────────────

  Future<void> _push() async {
    final unsynced = await _db.getUnsynced(limit: AppConstants.syncBatchSize);
    if (unsynced.isEmpty) return;

    await _api.pushItems(unsynced);

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final clip in unsynced) {
      await _db.markSynced(clip.id, now);
    }
  }

  // ── Pull ───────────────────────────────────────────────────────────────────

  Future<void> _pull() async {
    int since = _prefs.getInt(AppConstants.kLastSyncCursor) ?? 0;

    while (true) {
      final result = await _api.pullItems(
        since: since,
        limit: AppConstants.syncBatchSize,
      );

      if (result.items.isNotEmpty) {
        await _db.insertClips(result.items);
      }

      since = result.nextSince;
      await _prefs.setInt(AppConstants.kLastSyncCursor, since);

      if (!result.hasMore) break;
    }
  }
}
