import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/override_store.dart';
import '../../core/data/snapshot_manifest.dart';
import '../../core/theme/app_theme.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Header Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF281116), Color(0xFF141923)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: AppTheme.gold,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aegis Codex — Dota 2 reference',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Offline-first companion for Dota 2 players',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Legal Disclaimer Card
          Card(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gavel, size: 20, color: AppTheme.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unofficial — not affiliated with Valve Corporation. Dota 2 '
                      'and related marks are trademarks of Valve Corporation.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sources Section Header
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SOURCES',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Sources List
          Card(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.dataset, color: AppTheme.radiant),
                  title: Text(
                    'Reference data',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Valve datafeeds',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.photo_library, color: AppTheme.gold),
                  title: Text(
                    'Icons and videos',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Steam CDN',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.newspaper, color: AppTheme.primary),
                  title: Text(
                    'News',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Official Steam news feed',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.analytics, color: AppTheme.radiant),
                  title: Text(
                    'Draft matchup statistics',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'OpenDota public match aggregates',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Last Updated Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  'Last updated: $lastUpdated',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
