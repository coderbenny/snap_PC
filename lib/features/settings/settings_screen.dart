import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../clipboard/clipboard_notifier.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _activeSectionProvider = StateProvider<int>((_) => 0);

final _syncEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.kSyncEnabled) ?? true;
});

// ── Section definitions ────────────────────────────────────────────────────

const _sections = [
  _SectionMeta('Account', Icons.person_outline),
  _SectionMeta('Devices', Icons.devices_outlined),
  _SectionMeta('Preferences', Icons.tune_outlined),
  _SectionMeta('Data', Icons.storage_outlined),
  _SectionMeta('Danger Zone', Icons.warning_amber_outlined, isDestructive: true),
];

class _SectionMeta {
  final String label;
  final IconData icon;
  final bool isDestructive;
  const _SectionMeta(this.label, this.icon, {this.isDestructive = false});
}

// ── Screen ─────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          _SettingsSidebar(),
          const VerticalDivider(width: 1),
          const Expanded(child: _SettingsContent()),
        ],
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────

class _SettingsSidebar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_activeSectionProvider);
    final theme = Theme.of(context);

    return Container(
      width: 220,
      color: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_back, size: 18),
            title: const Text('Back', style: TextStyle(fontSize: 13)),
            onTap: () => context.go('/'),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'SETTINGS',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (int i = 0; i < _sections.length; i++)
            _SidebarItem(
              meta: _sections[i],
              selected: active == i,
              onTap: () => ref.read(_activeSectionProvider.notifier).state = i,
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _SectionMeta meta;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = meta.isDestructive
        ? Colors.red.shade400
        : selected
            ? scheme.primary
            : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(meta.icon, size: 17, color: color),
                const SizedBox(width: 10),
                Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(_activeSectionProvider);

    final (title, body) = switch (active) {
      0 => ('Account', const _AccountSection()),
      1 => ('Devices', const _DevicesSection()),
      2 => ('Preferences', const _PreferencesSection()),
      3 => ('Data', const _DataSection()),
      4 => ('Danger Zone', const _DangerSection()),
      _ => ('Account', const _AccountSection()),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const Divider(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: body,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Account section ────────────────────────────────────────────────────────

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return profile.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => _Card(
        child: Text(
          'Could not load profile: $e',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ),
      data: (data) {
        final email = data['email'] ?? '—';
        final plan = data['plan'] ?? 'free';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Card(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15),
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        _PlanBadge(plan: plan),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (plan == 'free')
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt,
                            size: 18, color: Colors.amber.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Upgrade to Pro',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get unlimited clip history, cross-device sync, '
                      'priority support, and early access to AI features.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    const _UpgradeButton(),
                  ],
                ),
              )
            else
              _Card(
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'You\'re on the ${_planLabel(plan)} plan. Thank you!',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  String _planLabel(String plan) => switch (plan) {
        'pro' => 'Pro',
        'pro_ai' => 'Pro + AI',
        'team' => 'Team',
        _ => 'Free',
      };
}

class _UpgradeButton extends ConsumerStatefulWidget {
  const _UpgradeButton();

  @override
  ConsumerState<_UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends ConsumerState<_UpgradeButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _upgrade,
      icon: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black54,
              ),
            )
          : const Icon(Icons.bolt, size: 16),
      label: Text(_loading ? 'Opening browser…' : 'Upgrade to Pro — \$5/mo'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.black,
      ),
    );
  }

  Future<void> _upgrade() async {
    setState(() => _loading = true);
    try {
      final url = await ref.read(apiClientProvider).getUpgradeLink('pro');
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open browser. Please try again.')),
          );
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        var msg = 'Could not open upgrade page. Please try again.';
        if (data is Map) {
          final err = data['error'];
          if (err is Map) msg = err['message']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open upgrade page. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Devices section ────────────────────────────────────────────────────────

final _devicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final key = ref.watch(encryptionKeyProvider);
  if (key == null) return [];
  return ref.read(apiClientProvider).listDevices();
});

class _DevicesSection extends ConsumerStatefulWidget {
  const _DevicesSection();

  @override
  ConsumerState<_DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends ConsumerState<_DevicesSection> {
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    ref.read(secureStorageProvider).getOrCreateDeviceId().then((id) {
      if (mounted) setState(() => _currentDeviceId = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(_devicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        devicesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (e, _) => _Card(
            child: Text(
              'Could not load devices: $e',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          data: (devices) {
            if (devices.isEmpty) {
              return _Card(
                child: Row(
                  children: [
                    Icon(Icons.devices_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(
                      'No devices registered yet.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: devices
                  .map((d) => _DeviceTile(
                        device: d,
                        isCurrent: d['id'] == _currentDeviceId,
                        onRevoke: () => _revoke(d['id'] as String),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Devices that have accessed your account. '
          'Revoking a device signs it out immediately.',
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _revoke(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke device?'),
        content: const Text(
          'This device will be signed out and removed from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).deleteDevice(deviceId);
      ref.invalidate(_devicesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke device: $e')),
        );
      }
    }
  }
}

class _DeviceTile extends StatelessWidget {
  final Map<String, dynamic> device;
  final bool isCurrent;
  final VoidCallback onRevoke;

  const _DeviceTile({
    required this.device,
    required this.isCurrent,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = device['platform'] as String? ?? '';
    final name = device['name'] as String? ?? 'Unknown';
    final version = device['app_version'] as String?;
    final lastSeen = device['last_seen_at'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Card(
        child: Row(
          children: [
            Icon(_platformIcon(platform),
                size: 22,
                color: isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'This device',
                            style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _platformLabel(platform),
                      if (version != null) 'v$version',
                      if (lastSeen != null)
                        'Last seen ${_formatDate(lastSeen)}',
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!isCurrent)
              TextButton(
                onPressed: onRevoke,
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                child: const Text('Revoke', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _platformIcon(String platform) => switch (platform) {
        'macos' => Icons.laptop_mac_outlined,
        'windows' => Icons.laptop_windows_outlined,
        'ios' => Icons.phone_iphone_outlined,
        'android' => Icons.phone_android_outlined,
        _ => Icons.devices_outlined,
      };

  static String _platformLabel(String platform) => switch (platform) {
        'macos' => 'macOS',
        'windows' => 'Windows',
        'ios' => 'iOS',
        'android' => 'Android',
        'web' => 'Web',
        _ => platform,
      };

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'yesterday';
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Preferences section ────────────────────────────────────────────────────

class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncEnabled = ref.watch(_syncEnabledProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: _ToggleRow(
            label: 'Enable sync',
            subtitle: 'Push and pull clips across your devices',
            value: syncEnabled,
            onChanged: (v) async {
              ref.read(_syncEnabledProvider.notifier).state = v;
              final prefs = ref.read(sharedPreferencesProvider);
              await prefs.setBool(AppConstants.kSyncEnabled, v);
            },
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App Info',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _InfoRow(
                  label: 'Platform',
                  value: Platform.isMacOS ? 'macOS' : 'Windows'),
              const SizedBox(height: 8),
              _InfoRow(label: 'Version', value: AppConstants.appVersion),
              const SizedBox(height: 8),
              _InfoRow(
                  label: 'Environment',
                  value: kReleaseMode ? 'Production' : 'Development'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Data section ───────────────────────────────────────────────────────────

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Local clip history',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Clears all clips stored on this device. Remote copies '
            'are not affected and will re-sync on next connection.',
            style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmClear(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined, size: 16),
            label: const Text('Clear local clips'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange),
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
            style:
                FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

// ── Danger section ─────────────────────────────────────────────────────────

class _DangerSection extends ConsumerWidget {
  const _DangerSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign out',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Removes your session and encryption key from this device. '
            'Your clips and account remain intact.',
            style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign out'),
            style:
                OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
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
    } catch (_) {}

    await storage.clearAll();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(AppConstants.kLastSyncCursor);

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
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant)),
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
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
