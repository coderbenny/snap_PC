import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/models/clip_item.dart';
import '../clipboard/clipboard_notifier.dart';

class QuickScreen extends ConsumerWidget {
  const QuickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(clipsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                  bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Quick Paste',
                    style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 15),
                  tooltip: 'Open main window',
                  onPressed: () async {
                    await _restoreMainWindow();
                    if (context.mounted) context.go('/');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 15),
                  tooltip: 'Hide',
                  onPressed: () => windowManager.hide(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Clip list
          Expanded(
            child: clips.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ),
              data: (all) {
                final items = all
                    .where((c) => !c.isDeleted)
                    .take(8)
                    .toList();

                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste_rounded,
                            size: 32, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Nothing copied yet',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (context, i) =>
                      _QuickClipTile(clip: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _restoreMainWindow() async {
    await windowManager.setSize(const Size(960, 660));
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  }
}

// ── Quick clip tile ────────────────────────────────────────────────────────

class _QuickClipTile extends ConsumerStatefulWidget {
  final ClipItem clip;
  const _QuickClipTile({required this.clip});

  @override
  ConsumerState<_QuickClipTile> createState() => _QuickClipTileState();
}

class _QuickClipTileState extends ConsumerState<_QuickClipTile> {
  bool _copied = false;

  Future<void> _paste() async {
    final text = widget.clip.plaintext ?? '';
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);

    // Brief flash, then collapse the quick window.
    await Future.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      await QuickScreen._restoreMainWindow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final theme = Theme.of(context);
    final text = clip.plaintext ?? '[encrypted]';

    return InkWell(
      onTap: _paste,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _typeIcon(clip.contentType),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text.length > 80 ? '${text.substring(0, 80)}…' : text,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _copied ? Icons.check : Icons.copy_outlined,
                key: ValueKey(_copied),
                size: 14,
                color: _copied
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeIcon(ContentType type) {
    final (icon, color) = switch (type) {
      ContentType.url => (Icons.link_rounded, Colors.blue),
      ContentType.image => (Icons.image_outlined, Colors.purple),
      ContentType.file => (Icons.insert_drive_file_outlined, Colors.orange),
      ContentType.text => (Icons.text_fields_rounded, Colors.white38),
    };
    return Icon(icon, size: 14, color: color);
  }
}
