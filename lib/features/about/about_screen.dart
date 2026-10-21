import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/override_store.dart';
import '../../core/data/snapshot_manifest.dart';

/// The refresh manifest feeding the "last updated" line; null means no
/// refresh has succeeded yet and the bundled snapshot is in use.
final snapshotManifestProvider = FutureProvider<SnapshotManifest?>(
  (ref) => ref.watch(overrideStoreProvider).readManifest(),
);

/// About screen: the "unofficial — not affiliated with Valve" disclaimer,
/// source attributions, and the last-updated line from the refresh manifest.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const routeLocation = '/about';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = ref.watch(snapshotManifestProvider);
    final lastUpdated = manifest.when(
      data: (m) => m == null
          ? 'bundled snapshot'
          : m.fetchedAt.toUtc().toIso8601String().substring(0, 10),
      loading: () => '…',
      error: (_, _) => 'bundled snapshot',
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Aegis Codex — Dota 2 reference',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unofficial — not affiliated with Valve Corporation. Dota 2 '
                'and related marks are trademarks of Valve Corporation.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('SOURCES', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('Reference data'),
                  subtitle: Text('Valve datafeeds'),
                ),
                ListTile(
                  title: Text('Icons and videos'),
                  subtitle: Text('Steam CDN'),
                ),
                ListTile(
                  title: Text('News'),
                  subtitle: Text('Official Steam news feed'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Last updated: $lastUpdated'),
        ],
      ),
    );
  }
}
