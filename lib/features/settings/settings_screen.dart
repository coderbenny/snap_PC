import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../clipboard/clipboard_notifier.dart';

// ── Local preferences provider ─────────────────────────────────────────────

final _syncEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.kSyncEnabled) ?? true;
});

// ── Screen ─────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          _SettingsSidebar(),
          const Expanded(child: _SettingsContent()),
        ],
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────

class _SettingsSidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_back, size: 18),
            title: const Text('Back', style: TextStyle(fontSize: 13)),
            onTap: () => context.go('/'),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Settings',
                style: theme.textTheme.labelSmall
                    ?.copyWith(letterSpacing: 0.5)),
          ),
          _SidebarItem(label: 'Account', icon: Icons.person_outline),
          _SidebarItem(label: 'Preferences', icon: Icons.tune_outlined),
          _SidebarItem(label: 'Data', icon: Icons.storage_outlined),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SidebarItem({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(36),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(context, 'Account'),
            const SizedBox(height: 12),
            const _AccountCard(),
            const SizedBox(height: 32),
            _sectionHeader(context, 'Preferences'),
            const SizedBox(height: 12),
            const _PreferencesCard(),
            const SizedBox(height: 32),
            _sectionHeader(context, 'Data'),
            const SizedBox(height: 12),
            const _DataCard(),
            const SizedBox(height: 32),
            _sectionHeader(context, 'Danger Zone'),
            const SizedBox(height: 12),
            const _DangerCard(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) => Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}

// ── Account card ───────────────────────────────────────────────────────────

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return _Card(
      child: profile.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Text('Could not load profile: $e',
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        data: (data) {
          final email = data['email'] ?? '—';
          final plan = data['plan'] ?? 'free';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        _PlanBadge(plan: plan),
                      ],
                    ),
                  ),
                ],
              ),
              if (plan == 'free') ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Text(
                  'Upgrade to Pro to enable cross-device sync, unlimited history, and more.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.bolt, size: 16),
                  label: const Text('Upgrade to Pro — \$5/mo'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (plan) {
      'pro' => ('Pro', Colors.indigo),
      'pro_ai' => ('Pro + AI', Colors.purple),
      'team' => ('Team', Colors.teal),
      _ => ('Free', Colors.white30),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Preferences card ───────────────────────────────────────────────────────

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncEnabled = ref.watch(_syncEnabledProvider);

    return _Card(
      child: Column(
        children: [
          _ToggleRow(
            label: 'Enable sync',
            subtitle: 'Push and pull clips across your devices',
            value: syncEnabled,
            onChanged: (v) async {
              ref.read(_syncEnabledProvider.notifier).state = v;
              final prefs = ref.read(sharedPreferencesProvider);
              await prefs.setBool(AppConstants.kSyncEnabled, v);
            },
          ),
          const Divider(height: 24),
          _InfoRow(
            label: 'Platform',
            value: Platform.isMacOS ? 'macOS' : 'Windows',
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'App version',
            value: AppConstants.appVersion,
          ),
        ],
      ),
    );
  }
}

// ── Data card ──────────────────────────────────────────────────────────────

class _DataCard extends ConsumerWidget {
  const _DataCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Local clip history',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Clears all clips stored on this device. Remote copies '
            'are not affected and will re-sync on next connection.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _confirmClear(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Clear local clips'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear local clips?'),
        content: const Text(
          'All clips on this device will be deleted. '
          'If you have sync enabled, they will re-download on the next sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(databaseServiceProvider).clearAll();
              ref.invalidate(clipsProvider);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ── Danger card ────────────────────────────────────────────────────────────

class _DangerCard extends ConsumerWidget {
  const _DangerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign out',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Removes your session and encryption key from this device. '
            'Your clips and account remain intact.',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your session will be cleared from this device. '
          'Sign in again to access your clips.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _logout(ref);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    final storage = ref.read(secureStorageProvider);
    final api = ref.read(apiClientProvider);

    try {
      final rt = await storage.getRefreshToken();
      if (rt != null) await api.logout(rt);
    } catch (_) {
      // Best-effort — clear local state regardless
    }

    await storage.clearAll();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(AppConstants.kLastSyncCursor);

    // Clearing the key triggers authListenableProvider → router redirects to /login.
    ref.read(encryptionKeyProvider.notifier).state = null;
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
