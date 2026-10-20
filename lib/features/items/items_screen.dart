import 'package:flutter/material.dart';

import '../../core/ui/placeholder_body.dart';

/// Items tab: will show Items grouped by shop category with a neutral-tier
/// filter. Placeholder content until a later ticket.
class ItemsScreen extends StatelessWidget {
  const ItemsScreen({super.key});

  static const routeLocation = '/items';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Items')),
      body: const PlaceholderBody(featureName: 'Items'),
    );
  }
}
