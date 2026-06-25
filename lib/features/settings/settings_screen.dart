import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Back sidebar
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.arrow_back, size: 18),
                  title: const Text('Back', style: TextStyle(fontSize: 13)),
                  onTap: () => context.go('/'),
                ),
              ],
            ),
          ),
          // Settings content
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  SizedBox(height: 24),
                  Text('Settings coming in Phase 6.',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
