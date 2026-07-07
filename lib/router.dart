import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/clipboard/clipboard_screen.dart';
import 'features/quick/quick_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/auth_shell.dart';
import 'features/transfer/transfer_history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.read(initialRouteProvider);
  final authListenable = ref.watch(authListenableProvider);

  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final isLoggedIn = authListenable.value;
      final loc = state.matchedLocation;
      final isOnAuth = loc == '/login' || loc == '/register';

      if (!isLoggedIn && !isOnAuth) return '/login';
      if (isLoggedIn && isOnAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/quick', builder: (_, _) => const QuickScreen()),

      // Authenticated screens share AuthShell, which owns the DropTarget and
      // incoming-transfer listener. ShellRoute puts the shell context inside
      // the GoRouter Navigator so showModalBottomSheet works correctly.
      ShellRoute(
        builder: (context, state, child) => AuthShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ClipboardScreen()),
          GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          GoRoute(path: '/transfers', builder: (_, _) => const TransferHistoryScreen()),
        ],
      ),
    ],
  );
});
