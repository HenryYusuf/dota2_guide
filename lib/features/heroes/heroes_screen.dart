import 'package:flutter/material.dart';

import '../../core/ui/placeholder_body.dart';

/// Heroes tab: will show the Hero grid with attribute/complexity filters.
/// Placeholder content until a later ticket.
class HeroesScreen extends StatelessWidget {
  const HeroesScreen({super.key});

  static const routeLocation = '/heroes';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heroes')),
      body: const PlaceholderBody(featureName: 'Heroes'),
    );
  }
}
