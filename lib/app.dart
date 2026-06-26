import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'router.dart';
import 'shared/theme/app_theme.dart';

class SnapApp extends ConsumerWidget {
  const SnapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep background services alive for the full app lifetime.
    ref.read(clipboardServiceProvider);
    ref.read(syncServiceProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SNAP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
