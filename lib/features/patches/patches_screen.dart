import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'latest_patch_card.dart';
import 'patch_detail_screen.dart';
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
        loading: () => const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
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
                LatestPatchCard(
                  patch: latest,
                  onTap: () => context.push(
                    PatchDetailScreen.location(latest.patchNumber),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PAST PATCHES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              for (final patch in olderPatches)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceHighlight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.history_edu,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      title: Text(
                        patch.patchName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        formatPatchDate(patch.releaseDate),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onTap: () => context.push(
                        PatchDetailScreen.location(patch.patchNumber),
                      ),
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
