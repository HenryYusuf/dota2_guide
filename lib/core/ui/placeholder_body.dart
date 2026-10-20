import 'package:flutter/material.dart';

/// Shared placeholder body for tabs whose real content ships in later
/// tickets. Clearly labelled as placeholder so it can't be mistaken for
/// finished UI. Long enough to scroll, so tab scroll-state preservation is
/// observable in tests.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.featureName});

  final String featureName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$featureName tab',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Placeholder — real $featureName content arrives in a '
                  'later ticket.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 1; i <= 30; i++)
          ListTile(title: Text('Placeholder row $i'), dense: true),
      ],
    );
  }
}
