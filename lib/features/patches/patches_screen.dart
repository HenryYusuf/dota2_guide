import 'package:flutter/material.dart';

import '../../core/ui/placeholder_body.dart';

/// Patches tab: will show the Patch list with the latest pinned on top.
/// Placeholder content until a later ticket.
class PatchesScreen extends StatelessWidget {
  const PatchesScreen({super.key});

  static const routeLocation = '/patches';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patches')),
      body: const PlaceholderBody(featureName: 'Patches'),
    );
  }
}
