import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/heroes/heroes_repository.dart';
import 'package:dota2_guide/features/items/items_repository.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patch_detail_repository.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';
import 'package:dota2_guide/features/patches/patches_repository.dart';

import '../../core/data/fake_datafeed_client.dart';
import '../../core/data/in_memory_file_store.dart';

class _FakeAssetLoader implements AssetLoader {
  final Map<String, String> assets = {};

  @override
  Future<String> readAsString(String path) async {
    final value = assets[path];
    if (value == null) throw Exception('Asset not found: $path');
    return value;
  }
}

void main() {
  group('SnapshotPatchesRepository', () {
    test('loads patch index from bundled asset fallback', () async {
      final fileStore = InMemoryFileStore();
      final overrideStore = OverrideStore(fileStore);
      final assetLoader = _FakeAssetLoader()
        ..assets[patchIndexAssetPath] = jsonEncode({
          'schema_version': patchIndexSchemaVersion,
          'locale': 'english',
          'patches': [
            {
              'patch_number': '7.41f',
              'patch_name': '7.41f',
              'timestamp': 1789455600,
            },
          ],
        });

      final source = SnapshotSource(
        overrides: overrideStore,
        assets: assetLoader,
      );
      final repo = SnapshotPatchesRepository(source);

      final index = await repo.loadPatchIndex();
      expect(index.patches.length, 1);
      expect(index.latestPatch?.patchNumber, '7.41f');
    });
  });

  group('LivePatchDetailRepository', () {
    const latestPatch = '7.41f';
    const olderPatch = '7.36';

    late InMemoryFileStore fileStore;
    late _FakeAssetLoader assetLoader;
    late FakeDatafeedClient feedClient;
    late LivePatchDetailRepository repo;

    setUp(() {
      fileStore = InMemoryFileStore();
      assetLoader = _FakeAssetLoader()
        ..assets[patchDetailAssetPath(latestPatch)] = jsonEncode({
          'schema_version': patchDetailSchemaVersion,
          'locale': 'english',
          'patch_number': latestPatch,
          'patch_name': latestPatch,
          'timestamp': 1789455600,
          'sections': [
            {
              'title': 'General',
              'groups': [
                {
                  'title': 'General Changes',
                  'lines': [
                    {'text': 'Bundled note', 'indent_level': 1},
                  ],
                },
              ],
            },
          ],
        });

      feedClient = FakeDatafeedClient();
      final source = SnapshotSource(
        overrides: OverrideStore(fileStore),
        assets: assetLoader,
      );

      repo = LivePatchDetailRepository(
        fileStore: fileStore,
        assetLoader: assetLoader,
        feedClient: feedClient,
        heroesRepository: SnapshotHeroesRepository(source),
        itemsRepository: SnapshotItemsRepository(source),
      );
    });

    test(
      'loads bundled patch from asset without network or fileStore',
      () async {
        final detail = await repo.loadPatchDetail(latestPatch);

        expect(detail.patchNumber, latestPatch);
        expect(
          detail.sections.first.groups.first.lines.first.text,
          'Bundled note',
        );
        expect(fileStore.files, isEmpty);
      },
    );

    test('on-demand fetch: fetches older patch, saves permanently to fileStore, returns detail', () async {
      feedClient
          .documents['$datafeedBaseUrl/patchnotes?version=$olderPatch&language=english'] = {
        'patch_number': olderPatch,
        'patch_name': olderPatch,
        'patch_timestamp': 1716361200,
        'general_notes': [
          {
            'title': 'General',
            'generic': [
              {'note': 'Older patch note', 'indent_level': 1},
            ],
          },
        ],
        'success': true,
      };

      final detail = await repo.loadPatchDetail(olderPatch);

      expect(detail.patchNumber, olderPatch);
      expect(
        detail.sections.first.groups.first.lines.first.text,
        'Older patch note',
      );

      // Verify permanently cached in fileStore
      final cached = await fileStore.readOrNull(
        'patches/patch_$olderPatch.english.json',
      );
      expect(cached, isNotNull);

      // Subsequent read hits fileStore even if feed document is removed
      feedClient.documents.clear();
      final cachedDetail = await repo.loadPatchDetail(olderPatch);
      expect(cachedDetail.patchNumber, olderPatch);
    });

    test(
      'failure path: propagates network error when on-demand fetch fails',
      () async {
        // feedClient has no document for olderPatch, will throw
        expect(
          () => repo.loadPatchDetail(olderPatch),
          throwsA(isA<Exception>()),
        );

        // Nothing written to fileStore on failure
        expect(
          await fileStore.readOrNull('patches/patch_$olderPatch.english.json'),
          isNull,
        );
      },
    );
  });
}
