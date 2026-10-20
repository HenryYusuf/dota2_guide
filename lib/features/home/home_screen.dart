import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/placeholder_body.dart';
import '../about/about_screen.dart';

/// Home tab: will show the latest-Patch card and Valve news feed.
/// Placeholder content until a later ticket.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const routeLocation = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aegis Codex'),
        actions: [
          // Top-bar menu: currently only About; the last-updated line and
          // source attributions slot in here too (spec navigation decision).
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onSelected: (value) {
              if (value == 'about') {
                context.push(AboutScreen.routeLocation);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('About & sources')),
            ],
          ),
        ],
      ),
      body: const PlaceholderBody(featureName: 'Home'),
    );
  }
}
