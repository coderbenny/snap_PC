import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/clip_item.dart';
import '../../core/providers.dart';
import 'clipboard_notifier.dart';

// ── Screen ─────────────────────────────────────────────────────────────────

class ClipboardScreen extends ConsumerStatefulWidget {
  const ClipboardScreen({super.key});

  @override
  ConsumerState<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends ConsumerState<ClipboardScreen> {
  @override
  void initState() {
    super.initState();
    // Listen for plan upgrades and surface a banner so the user notices
    // immediately without having to visit Settings.
    ref.listenManual(planUpgradeNoticeProvider, (_, upgraded) {
      if (!upgraded || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: Colors.amber.shade800,
          duration: const Duration(seconds: 6),
          content: const Row(
            children: [
              Icon(Icons.bolt, color: Colors.black, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You\'re now on Pro — sync is enabled!',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.black87,
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      // Reset the flag so it doesn't re-fire on rebuild.
      ref.read(planUpgradeNoticeProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(),
          const Expanded(child: _ClipList()),
        ],
      ),
    );
  }
}

// ── Sidebar ────────────────────────────────────────────────────────────────

final _typeFilterProvider = StateProvider<ContentType?>((ref) => null);
final _searchProvider = StateProvider<String>((ref) => '');

class _Sidebar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_typeFilterProvider);
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Snapit',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(letterSpacing: 1)),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'All clips',
            icon: Icons.copy_all_outlined,
            active: filter == null,
            onTap: () => ref.read(_typeFilterProvider.notifier).state = null,
          ),
          _SidebarItem(
            label: 'Text',
            icon: Icons.text_fields_rounded,
            active: filter == ContentType.text,
            onTap: () =>
                ref.read(_typeFilterProvider.notifier).state = ContentType.text,
          ),
          _SidebarItem(
            label: 'URLs',
            icon: Icons.link_rounded,
            active: filter == ContentType.url,
            onTap: () =>
                ref.read(_typeFilterProvider.notifier).state = ContentType.url,
          ),
          _SidebarItem(
            label: 'Pinned',
            icon: Icons.push_pin_outlined,
            active: filter == ContentType.image, // reuse slot for pinned
            onTap: () {},
          ),
          const Spacer(),
          const Divider(height: 1),
          _SyncStatusTile(),
          ListTile(
            leading: const Icon(Icons.settings_outlined, size: 18),
            title: const Text('Settings', style: TextStyle(fontSize: 13)),
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    final (icon, label, color) = switch (status) {
      SyncStatus.syncing => (Icons.sync, 'Syncing…', theme.colorScheme.primary),
      SyncStatus.error => (Icons.sync_problem_outlined, 'Sync error', Colors.red),
      SyncStatus.upgradeRequired => (
          Icons.cloud_off_outlined,
          'Upgrade to sync',
          theme.colorScheme.onSurfaceVariant
        ),
      SyncStatus.idle => (
          Icons.cloud_done_outlined,
          'Synced',
          theme.colorScheme.onSurfaceVariant
        ),
    };

    return ListTile(
      dense: true,
      leading: status == SyncStatus.syncing
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: color),
            )
          : Icon(icon, size: 16, color: color),
      title: Text(label,
          style: TextStyle(fontSize: 12, color: color)),
      trailing: status != SyncStatus.syncing && status != SyncStatus.upgradeRequired
          ? Tooltip(
              message: 'Sync now',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => ref.read(syncServiceProvider).syncNow(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh, size: 14, color: Colors.white30),
                ),
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return ListTile(
      dense: true,
      leading: Icon(icon,
          size: 17, color: active ? primary : theme.colorScheme.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          color: active ? primary : theme.colorScheme.onSurface,
        ),
      ),
      tileColor: active ? primary.withValues(alpha: 0.1) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
    );
  }
}

// ── Clip list ──────────────────────────────────────────────────────────────

class _ClipList extends ConsumerWidget {
  const _ClipList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(clipsProvider);
    final filter = ref.watch(_typeFilterProvider);
    final search = ref.watch(_searchProvider);

    return Column(
      children: [
        _SearchBar(),
        Expanded(
          child: clips.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: Colors.white38)),
            ),
            data: (all) {
              var items = all.where((c) => !c.isDeleted).toList();

              // Count clips whose decryption failed — shown as a banner so
              // the user understands why some clips appear as [encrypted].
              final failedCount =
                  items.where((c) => c.plaintext == null).length;

              if (filter != null) {
                items = items.where((c) => c.contentType == filter).toList();
              }

              if (search.isNotEmpty) {
                final q = search.toLowerCase();
                items = items
                    .where((c) =>
                        c.plaintext?.toLowerCase().contains(q) ?? false)
                    .toList();
              }

              if (items.isEmpty) return const _EmptyState();

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length + (failedCount > 0 ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == 0 && failedCount > 0) {
                    return _DecryptFailureBanner(
                        failedCount: failedCount, total: all.length);
                  }
                  final idx = failedCount > 0 ? i - 1 : i;
                  return _ClipCard(clip: items[idx]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search clips…',
          prefixIcon: const Icon(Icons.search, size: 18),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        onChanged: (v) =>
            ref.read(_searchProvider.notifier).state = v,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_paste_rounded,
              size: 48, color: Colors.white24),
          SizedBox(height: 16),
          Text('No clips yet',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
          SizedBox(height: 6),
          Text('Copy anything to see it appear here.',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Decrypt failure banner ────────────────────────────────────────────────

class _DecryptFailureBanner extends StatelessWidget {
  final int failedCount;
  final int total;

  const _DecryptFailureBanner(
      {required this.failedCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final allFailed = failedCount == total;
    final message = allFailed
        ? 'None of your clips could be decrypted. Sign out and sign back in to re-enter your password.'
        : '$failedCount clip${failedCount == 1 ? '' : 's'} could not be decrypted. '
            'They may have been saved by an older version of the app.';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.25),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.amber.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 12, color: Colors.amber.shade300),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clip card ──────────────────────────────────────────────────────────────

class _ClipCard extends ConsumerStatefulWidget {
  final ClipItem clip;
  const _ClipCard({required this.clip});

  @override
  ConsumerState<_ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends ConsumerState<_ClipCard> {
  bool _copied = false;
  bool _expanded = false;

  static const _previewLimit = 200;

  void _copy() async {
    final text = widget.clip.plaintext ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final theme = Theme.of(context);
    final text = clip.plaintext ?? '[encrypted]';
    final isLong = text.length > _previewLimit;
    final displayText =
        (!_expanded && isLong) ? '${text.substring(0, _previewLimit)}…' : text;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: _TypeIcon(type: clip.contentType),
                ),
                // Content
                Expanded(
                  child: GestureDetector(
                    onTap: isLong
                        ? () => setState(() => _expanded = !_expanded)
                        : null,
                    child: Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: theme.colorScheme.onSurface,
                        fontFamily: clip.contentType == ContentType.text
                            ? null
                            : 'monospace',
                      ),
                    ),
                  ),
                ),
                // Actions
                _CardActions(
                  clip: clip,
                  copied: _copied,
                  onCopy: _copy,
                  onDelete: () =>
                      ref.read(clipsProvider.notifier).deleteClip(clip.id),
                  onPin: () =>
                      ref.read(clipsProvider.notifier).togglePin(clip.id),
                ),
              ],
            ),
            // Footer
            const SizedBox(height: 6),
            Row(
              children: [
                if (clip.pinned) ...[
                  Icon(Icons.push_pin,
                      size: 11,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                ],
                Text(
                  _formatTime(clip.clientCreatedAt),
                  style: theme.textTheme.labelSmall,
                ),
                if (isLong) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'Show less' : 'Show more',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

class _TypeIcon extends StatelessWidget {
  final ContentType type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      ContentType.url => (Icons.link_rounded, Colors.blue),
      ContentType.image => (Icons.image_outlined, Colors.purple),
      ContentType.file => (Icons.insert_drive_file_outlined, Colors.orange),
      ContentType.text => (Icons.text_fields_rounded, Colors.white38),
    };
    return Icon(icon, size: 15, color: color);
  }
}

class _CardActions extends StatelessWidget {
  final ClipItem clip;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const _CardActions({
    required this.clip,
    required this.copied,
    required this.onCopy,
    required this.onDelete,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: copied ? Icons.check : Icons.copy_outlined,
          tooltip: copied ? 'Copied!' : 'Copy',
          color: copied ? Colors.green : null,
          onTap: onCopy,
        ),
        _ActionButton(
          icon: clip.pinned ? Icons.push_pin : Icons.push_pin_outlined,
          tooltip: clip.pinned ? 'Unpin' : 'Pin',
          color: clip.pinned
              ? Theme.of(context).colorScheme.primary
              : null,
          onTap: onPin,
        ),
        _ActionButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete',
          color: Colors.red.withValues(alpha: 0.7),
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 16,
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
