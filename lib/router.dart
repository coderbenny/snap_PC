import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/clipboard/clipboard_screen.dart';
import 'features/quick/quick_screen.dart';
import 'features/settings/settings_screen.dart';

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
      GoRoute(path: '/', builder: (_, _) => const ClipboardScreen()),
      GoRoute(path: '/quick', builder: (_, _) => const QuickScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
