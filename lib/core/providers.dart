import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/api_client.dart';
import 'services/database_service.dart';
import 'services/secure_storage_service.dart';

export 'services/api_client.dart';
export 'services/database_service.dart';
export 'services/encryption_service.dart';
export 'services/secure_storage_service.dart';

/// Provided via ProviderScope overrides after async init in main().
final databaseServiceProvider = Provider<DatabaseService>((_) {
  throw UnimplementedError('databaseServiceProvider must be overridden in ProviderScope');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

/// In-memory AES key (32 bytes). Null until the user logs in / unlocks.
final encryptionKeyProvider = StateProvider<Uint8List?>((ref) => null);

/// True when the user has a stored access token (i.e. is logged in).
final hasSessionProvider = FutureProvider<bool>((ref) {
  return ref.read(secureStorageProvider).hasSession();
});
