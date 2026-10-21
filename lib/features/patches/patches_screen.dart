import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'patch_detail_screen.dart';
import 'patch_index.dart';
import 'patches_providers.dart';

/// Formats a UTC date as "Month Day, Year" (e.g. "September 15, 2026").
String formatPatchDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Patches tab: lists patches with the latest pinned at the top.
class PatchesScreen extends ConsumerWidget {
  const PatchesScreen({super.key});

  static const routeLocation = '/patches';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patchesAsync = ref.watch(patchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Patches')),
      body: patchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text("Couldn't load patches.")),
        data: (index) {
          final patches = index.patches;
          if (patches.isEmpty) {
            return const Center(child: Text('No patches found.'));
          }

          final latest = index.latestPatch;
          final olderPatches = latest == null
              ? patches
              : patches
                    .where((p) => p.patchNumber != latest.patchNumber)
                    .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (latest != null) ...[
                _PinnedLatestPatchCard(
                  patch: latest,
                  onTap: () => context.push(
                    PatchDetailScreen.location(latest.patchNumber),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PAST PATCHES',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final patch in olderPatches)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      patch.patchName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      formatPatchDate(patch.releaseDate),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
                    onTap: () => context.push(
                      PatchDetailScreen.location(patch.patchNumber),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PinnedLatestPatchCard extends StatelessWidget {
  const _PinnedLatestPatchCard({required this.patch, required this.onTap});

  final PatchSummary patch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Latest Patch',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                patch.patchName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatPatchDate(patch.releaseDate),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
