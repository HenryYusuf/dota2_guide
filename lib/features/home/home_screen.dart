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
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'About & sources',
            onPressed: () => context.push(AboutScreen.routeLocation),
          ),
        ],
      ),
      body: const PlaceholderBody(featureName: 'Home'),
    );
  }
}
