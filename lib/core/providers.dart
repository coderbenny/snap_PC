import 'package:flutter/foundation.dart';
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

/// Starting route determined in main() after session check.
/// Override in ProviderScope to set '/' when a stored key is found.
final initialRouteProvider = Provider<String>((_) => '/login');

/// ValueNotifier that mirrors [encryptionKeyProvider] — used as
/// GoRouter.refreshListenable so the router re-evaluates its redirect
/// whenever the user logs in or out.
final authListenableProvider = Provider<ValueNotifier<bool>>((ref) {
  final notifier = ValueNotifier<bool>(ref.read(encryptionKeyProvider) != null);
  ref.listen(encryptionKeyProvider, (_, next) {
    notifier.value = next != null;
  });
  return notifier;
});
