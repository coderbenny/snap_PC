import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/clip_item.dart';
import '../../core/providers.dart';

final clipsProvider =
    AsyncNotifierProvider<ClipsNotifier, List<ClipItem>>(ClipsNotifier.new);

class ClipsNotifier extends AsyncNotifier<List<ClipItem>> {
  @override
  Future<List<ClipItem>> build() async {
    final key = ref.watch(encryptionKeyProvider);
    if (key == null) return [];

    // Re-fetch from DB whenever the sync engine completes a pull.
    ref.watch(lastSyncProvider);

    // Wire clipboard service → prepend new clips as they arrive.
    final service = ref.read(clipboardServiceProvider);
    service.onNewClip = _prepend;

    final db = ref.read(databaseServiceProvider);
    final clips = await db.getClips(limit: 200);
    return _decryptAll(clips, key);
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<void> deleteClip(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.markDeleted(id);
    state.whenData(
      (clips) => state = AsyncData(clips.where((c) => c.id != id).toList()),
    );
  }

  /// Remove locally-cached clips that could not be decrypted.
  /// Only clips already synced to the server are deleted — they will
  /// reappear automatically on the next sync pull. Local-only clips that
  /// cannot be decrypted are kept (the user may fix the key by signing out
  /// and back in with the correct password).
  Future<void> removeUndecryptable() async {
    final clips = state.valueOrNull;
    if (clips == null) return;

    final syncedBad = clips
        .where((c) => c.plaintext == null && c.isSynced)
        .toList();
    if (syncedBad.isEmpty) return;

    // Optimistic UI update first — no await, so the screen never blanks.
    state = AsyncData(
      clips.where((c) => !(c.plaintext == null && c.isSynced)).toList(),
    );

    final db = ref.read(databaseServiceProvider);
    await db.deleteByIds(syncedBad.map((c) => c.id).toList());
  }

  Future<void> togglePin(String id) async {
    final db = ref.read(databaseServiceProvider);
    state.whenData((clips) {
      final clip = clips.firstWhere((c) => c.id == id);
      db.setPinned(id, !clip.pinned);
      final updated = [
        for (final c in clips)
          if (c.id == id) c.copyWith(pinned: !c.pinned) else c,
      ]..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.clientCreatedAt.compareTo(a.clientCreatedAt);
        });
      state = AsyncData(updated);
    });
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _prepend(ClipItem clip) {
    state.whenData(
      (clips) => state = AsyncData([clip, ...clips]),
    );
  }

  static List<ClipItem> _decryptAll(List<ClipItem> clips, Uint8List key) {
    return [
      for (final c in clips)
        () {
          try {
            return c.copyWith(
                plaintext: EncryptionService.decrypt(key, c.ciphertext, c.iv));
          } catch (_) {
            return c;
          }
        }(),
    ]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.clientCreatedAt.compareTo(a.clientCreatedAt);
      });
  }
}
