import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/patches/hero_patch_deltas_repository.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';

import '../../core/data/in_memory_file_store.dart';

class _FakeAssetLoader implements AssetLoader {
  _FakeAssetLoader(this.payload);

  final String payload;

  @override
  Future<String> readAsString(String assetPath) async => payload;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SnapshotSource fakeSource(String payload) => SnapshotSource(
    overrides: OverrideStore(InMemoryFileStore()),
    assets: _FakeAssetLoader(payload),
  );

  group('HeroPatchHistory & Repository', () {
    final sampleJson = {
      'schema_version': 1,
      'locale': 'english',
      'heroes': <String, dynamic>{
        '1': {
          'hero_id': 1,
          'deltas': [
            {
              'patch_number': '7.41f',
              'patch_name': '7.41f',
              'timestamp': 1789455600,
              'stats': <Map<String, dynamic>>[],
              'talents': [
                {
                  'text': 'Level 15 Talent Mana Void Cooldown reduced',
                  'indent_level': 1,
                },
              ],
              'abilities': [
                {
                  'ability_id': 5003,
                  'ability_name': 'antimage_mana_break',
                  'lines': [
                    {
                      'text': 'Mana Burned as Damage increased from 60% to 65%',
                      'indent_level': 1,
                    },
                  ],
                },
              ],
            },
            {
              'patch_number': '7.41d',
              'patch_name': '7.41d',
              'timestamp': 1780556400,
              'stats': [
                {
                  'text': 'Base Agility increased from 24 to 25',
                  'indent_level': 1,
                },
              ],
              'talents': <Map<String, dynamic>>[],
              'abilities': [
                {
                  'ability_id': 5004,
                  'ability_name': 'antimage_blink',
                  'lines': [
                    {
                      'text':
                          'Mana Cost decreased from 65/60/55/50 to 60/55/50/45',
                      'indent_level': 1,
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    };

    test('parses HeroPatchHistory and helper methods find ability deltas', () {
      final heroHistory = HeroPatchHistory.fromJson(
        1,
        (sampleJson['heroes'] as Map)['1'] as Map<String, dynamic>,
      );

      expect(heroHistory.heroId, 1);
      expect(heroHistory.deltas.length, 2);

      final latestPatch = heroHistory.latestPatchForAbility(
        'antimage_mana_break',
      );
      expect(latestPatch, '7.41f');

      final blinkPatch = heroHistory.latestPatchForAbility('antimage_blink');
      expect(blinkPatch, '7.41d');

      final unknownPatch = heroHistory.latestPatchForAbility(
        'antimage_counterspell',
      );
      expect(unknownPatch, isNull);

      final manaBreakDeltas = heroHistory.deltasForAbility(
        'antimage_mana_break',
      );
      expect(manaBreakDeltas.length, 1);
      expect(manaBreakDeltas[0].patchNumber, '7.41f');
      expect(
        manaBreakDeltas[0].lines[0].text,
        'Mana Burned as Damage increased from 60% to 65%',
      );
    });

    test(
      'SnapshotHeroPatchDeltaRepository loads hero history from source',
      () async {
        final source = fakeSource(jsonEncode(sampleJson));
        final repo = SnapshotHeroPatchDeltaRepository(source);

        final amHistory = await repo.loadHeroPatchHistory(1);
        expect(amHistory.heroId, 1);
        expect(amHistory.deltas.length, 2);

        // Hero with no patch deltas returns empty history gracefully
        final emptyHistory = await repo.loadHeroPatchHistory(999);
        expect(emptyHistory.heroId, 999);
        expect(emptyHistory.deltas, isEmpty);
      },
    );

    test(
      'heroPatchHistoryProvider yields HeroPatchHistory in container',
      () async {
        final container = ProviderContainer(
          overrides: [
            heroPatchDeltaRepositoryProvider.overrideWithValue(
              SnapshotHeroPatchDeltaRepository(
                fakeSource(jsonEncode(sampleJson)),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final history = await container.read(
          heroPatchHistoryProvider(1).future,
        );
        expect(history.heroId, 1);
        expect(history.deltas.length, 2);
      },
    );
  });
}
