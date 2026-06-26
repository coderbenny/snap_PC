import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_client.dart';
import 'services/clipboard_service.dart';
import 'services/database_service.dart';
import 'services/secure_storage_service.dart';
import 'services/sync_service.dart';

export 'services/api_client.dart';
export 'services/clipboard_service.dart';
export 'services/database_service.dart';
export 'services/encryption_service.dart';
export 'services/secure_storage_service.dart';
export 'services/sync_service.dart';

/// Provided via ProviderScope overrides after async init in main().
final databaseServiceProvider = Provider<DatabaseService>((_) {
  throw UnimplementedError('databaseServiceProvider must be overridden in ProviderScope');
});

/// Provided via ProviderScope overrides after async init in main().
final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
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

/// Unix-ms timestamp bumped after each successful sync cycle.
/// ClipsNotifier watches this to trigger a DB reload after a pull.
final lastSyncProvider = StateProvider<int>((_) => 0);

/// Current sync status — drives the UI indicator in the sidebar.
final syncStatusProvider = StateProvider<SyncStatus>((_) => SyncStatus.idle);

/// Singleton sync engine — starts periodic sync on login, stops on logout.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    api: ref.read(apiClientProvider),
    db: ref.read(databaseServiceProvider),
    prefs: ref.read(sharedPreferencesProvider),
  );

  service.onStatusChange =
      (status) => ref.read(syncStatusProvider.notifier).state = status;

  service.onSyncComplete =
      () => ref.read(lastSyncProvider.notifier).state =
          DateTime.now().millisecondsSinceEpoch;

  ref.listen(encryptionKeyProvider, (_, key) {
    if (key != null) {
      service.start();
    } else {
      service.stop();
    }
  });

  final initialKey = ref.read(encryptionKeyProvider);
  if (initialKey != null) service.start();

  ref.onDispose(service.stop);
  return service;
});

/// Singleton clipboard watcher — starts/stops automatically as the
/// encryption key is set or cleared (login / logout).
final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final service = ClipboardService(
    db: ref.read(databaseServiceProvider),
    storage: ref.read(secureStorageProvider),
  );

  ref.listen(encryptionKeyProvider, (_, key) {
    if (key != null) {
      service.start(key);
    } else {
      service.stop();
    }
  });

  final initialKey = ref.read(encryptionKeyProvider);
  if (initialKey != null) service.start(initialKey);

  ref.onDispose(service.stop);
  return service;
});
