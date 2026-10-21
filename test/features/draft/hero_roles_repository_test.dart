import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/draft/hero_roles_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/in_memory_file_store.dart';

class _FakeAssetLoader implements AssetLoader {
  _FakeAssetLoader(this.content);

  final String content;

  @override
  Future<String> readAsString(String assetPath) async {
    return content;
  }
}

void main() {
  group('SnapshotHeroRolesRepository', () {
    test(
      'deserializes hero roles JSON map into typed HeroRoleLevels map',
      () async {
        final sampleJson = jsonEncode({
          '1': [3, 0, 1, 0, 0, 0, 3, 0, 0],
          '2': [1, 0, 0, 2, 0, 3, 0, 0, 3],
        });

        final source = SnapshotSource(
          overrides: OverrideStore(InMemoryFileStore()),
          assets: _FakeAssetLoader(sampleJson),
        );
        final repository = SnapshotHeroRolesRepository(source);
        final roles = await repository.loadHeroRoles();

        expect(roles.length, 2);
        expect(roles[1]?.carry, 3);
        expect(roles[1]?.escape, 3);
        expect(roles[2]?.durable, 3);
        expect(roles[2]?.initiator, 3);
      },
    );

    test('throws FormatException when JSON is not an object', () async {
      final source = SnapshotSource(
        overrides: OverrideStore(InMemoryFileStore()),
        assets: _FakeAssetLoader('[]'),
      );
      final repository = SnapshotHeroRolesRepository(source);
      expect(() => repository.loadHeroRoles(), throwsFormatException);
    });

    test('successfully parses committed bundled hero_roles.json asset', () {
      final file = File('assets/data/hero_roles.json');
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json.length, 127);

      // Verify Anti-Mage (ID: 1)
      final am = json['1'] as List<dynamic>;
      expect(am[0], 3); // Carry: 3

      // Verify Axe (ID: 2)
      final axe = json['2'] as List<dynamic>;
      expect(axe[5], 3); // Durable: 3
      expect(axe[8], 3); // Initiator: 3
    });
  });
}
