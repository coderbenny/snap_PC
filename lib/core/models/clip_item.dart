enum ContentType { text, url, image, file }

ContentType contentTypeFromString(String s) =>
    ContentType.values.firstWhere((e) => e.name == s, orElse: () => ContentType.text);

class ClipItem {
  final String id;
  final String ciphertext;
  final String iv;
  final ContentType contentType;
  final List<String> tags;
  final bool pinned;
  final String? deviceId;
  final int clientCreatedAt; // Unix ms
  final int syncedAt; // Unix ms, 0 if not yet synced
  final bool isSynced;
  final bool isDeleted;

  // Decrypted — only populated in memory, never persisted
  final String? plaintext;

  const ClipItem({
    required this.id,
    required this.ciphertext,
    required this.iv,
    required this.contentType,
    this.tags = const [],
    this.pinned = false,
    this.deviceId,
    required this.clientCreatedAt,
    this.syncedAt = 0,
    this.isSynced = false,
    this.isDeleted = false,
    this.plaintext,
  });

  ClipItem copyWith({
    String? plaintext,
    bool? isSynced,
    int? syncedAt,
    bool? isDeleted,
    bool? pinned,
  }) {
    return ClipItem(
      id: id,
      ciphertext: ciphertext,
      iv: iv,
      contentType: contentType,
      tags: tags,
      pinned: pinned ?? this.pinned,
      deviceId: deviceId,
      clientCreatedAt: clientCreatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      plaintext: plaintext ?? this.plaintext,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ciphertext': ciphertext,
        'iv': iv,
        'content_type': contentType.name,
        'tags': tags.join(','),
        'pinned': pinned ? 1 : 0,
        'device_id': deviceId,
        'client_created_at': clientCreatedAt,
        'synced_at': syncedAt,
        'is_synced': isSynced ? 1 : 0,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory ClipItem.fromMap(Map<String, dynamic> m) => ClipItem(
        id: m['id'] as String,
        ciphertext: m['ciphertext'] as String,
        iv: m['iv'] as String,
        contentType: contentTypeFromString(m['content_type'] as String),
        tags: (m['tags'] as String).isEmpty
            ? []
            : (m['tags'] as String).split(','),
        pinned: (m['pinned'] as int) == 1,
        deviceId: m['device_id'] as String?,
        clientCreatedAt: m['client_created_at'] as int,
        syncedAt: m['synced_at'] as int,
        isSynced: (m['is_synced'] as int) == 1,
        isDeleted: (m['is_deleted'] as int) == 1,
      );

  /// Build a ClipItem from a backend sync payload (already decrypted separately).
  factory ClipItem.fromApi(Map<String, dynamic> j) => ClipItem(
        id: j['id'] as String,
        ciphertext: j['ciphertext'] as String,
        iv: j['iv'] as String,
        contentType: contentTypeFromString(j['content_type'] as String? ?? 'text'),
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        pinned: j['pinned'] as bool? ?? false,
        deviceId: j['device_id'] as String?,
        clientCreatedAt: j['client_created_at'] as int,
        syncedAt: j['synced_at'] as int? ?? 0,
        isSynced: true,
        isDeleted: j['deleted_at'] != null,
      );
}
