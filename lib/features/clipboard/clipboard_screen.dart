import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ClipboardScreen extends StatelessWidget {
  const ClipboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _Sidebar(),
          // Content
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.content_paste_rounded, size: 48, color: Colors.white38),
                  SizedBox(height: 16),
                  Text('No clips yet', style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 8),
                  Text(
                    'Copy something to see it here.',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).cardColor;
    final border = Theme.of(context).dividerColor;
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: color,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.content_paste_rounded,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('SNAP',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(letterSpacing: 1)),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(child: SizedBox()),
          // Settings link
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
