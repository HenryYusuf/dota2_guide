import 'package:flutter/material.dart';

/// About screen: will carry the "unofficial — not affiliated with Valve"
/// disclaimer, source attributions, and the last-updated line.
/// Stub content until a later ticket.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const routeLocation = '/about';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About tab',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Placeholder — disclaimer, source attributions, and the '
                    'last-updated line arrive in a later ticket.',
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
