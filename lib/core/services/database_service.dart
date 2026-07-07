import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/clip_item.dart';

class DatabaseService {
  static Database? _db;

  Future<void> initialize() async {
    if (_db != null) return;
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'snap.db');

    _db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE clips (
              id               TEXT    PRIMARY KEY,
              ciphertext       TEXT    NOT NULL,
              iv               TEXT    NOT NULL,
              content_type     TEXT    NOT NULL DEFAULT 'text',
              tags             TEXT    NOT NULL DEFAULT '',
              pinned           INTEGER NOT NULL DEFAULT 0,
              device_id        TEXT,
              client_created_at INTEGER NOT NULL,
              synced_at        INTEGER NOT NULL DEFAULT 0,
              is_synced        INTEGER NOT NULL DEFAULT 0,
              is_deleted       INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_clips_created ON clips(client_created_at DESC)');
          await db.execute(
              'CREATE INDEX idx_clips_synced  ON clips(is_synced)');
        },
      ),
    );
  }

  Database get _database {
    assert(_db != null, 'DatabaseService.initialize() must be called first');
    return _db!;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> insertClip(ClipItem clip) async {
    await _database.insert(
      'clips',
      clip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertClips(List<ClipItem> clips) async {
    if (clips.isEmpty) return;
    final batch = _database.batch();
    for (final clip in clips) {
      batch.insert('clips', clip.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> markSynced(String id, int syncedAt) async {
    await _database.update(
      'clips',
      {'is_synced': 1, 'synced_at': syncedAt},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markDeleted(String id) async {
    await _database.update(
      'clips',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPinned(String id, bool pinned) async {
    await _database.update(
      'clips',
      {'pinned': pinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<ClipItem>> getClips({
    int limit = 200,
    int offset = 0,
    String? contentType,
  }) async {
    final where = contentType != null
        ? 'is_deleted = 0 AND content_type = ?'
        : 'is_deleted = 0';
    final whereArgs = contentType != null ? [contentType] : null;

    final rows = await _database.query(
      'clips',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'client_created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(ClipItem.fromMap).toList();
  }

  Future<List<ClipItem>> getUnsynced({int limit = 500}) async {
    final rows = await _database.query(
      'clips',
      where: 'is_synced = 0 AND is_deleted = 0',
      orderBy: 'client_created_at ASC',
      limit: limit,
    );
    return rows.map(ClipItem.fromMap).toList();
  }

  Future<int> getTotalCount() async {
    final result = await _database
        .rawQuery('SELECT COUNT(*) as c FROM clips WHERE is_deleted = 0');
    return result.first['c'] as int;
  }

  Future<void> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final batch = _database.batch();
    for (final id in ids) {
      batch.delete('clips', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAll() async {
    await _database.delete('clips');
  }
}
