import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../about/about_screen.dart';
import '../heroes/heroes_screen.dart';
import '../items/items_screen.dart';
import '../patches/patch_detail_screen.dart';
import '../patches/patches_providers.dart';
import '../patches/patches_screen.dart' show formatPatchDate;
import 'home_providers.dart';
import 'news_repository.dart';

/// Home tab: latest-Patch card, quick entries, and Valve news. Bundled data
/// drives everything but news, and a news failure is a small inline retry —
/// never a full-screen error.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const routeLocation = '/';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(patchesProvider).asData?.value.latestPatch;
    final newsAsync = ref.watch(newsProvider);

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (latest != null)
            Card(
              color: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              child: ListTile(
                title: const Text('Latest Patch'),
                subtitle: Text(
                  '${latest.patchName} · ${formatPatchDate(latest.releaseDate)}',
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () =>
                    context.go(PatchDetailScreen.location(latest.patchNumber)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickEntry(
                  icon: Icons.groups,
                  label: 'Heroes',
                  onTap: () => context.go(HeroesScreen.routeLocation),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickEntry(
                  icon: Icons.shopping_bag,
                  label: 'Items',
                  onTap: () => context.go(ItemsScreen.routeLocation),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'VALVE NEWS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white60,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          newsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off),
                title: const Text("Couldn't load news."),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(newsProvider),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (items) => Column(
              children: [
                for (final item in items)
                  _NewsTile(
                    item: item,
                    onTap: () => ref
                        .read(externalUrlLauncherProvider)
                        .call(Uri.parse(item.url)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEntry extends StatelessWidget {
  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [Icon(icon), const SizedBox(height: 4), Text(label)],
          ),
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  const _NewsTile({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(
          formatPatchDate(item.date),
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: const Icon(Icons.open_in_new, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
