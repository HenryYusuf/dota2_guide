import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/core/data/asset_loader.dart';
import 'package:dota2_guide/core/data/override_store.dart';
import 'package:dota2_guide/core/data/snapshot_source.dart';
import 'package:dota2_guide/features/draft/matchup_matrix_repository.dart';

import '../../core/data/in_memory_file_store.dart';

class _FakeAssetLoader implements AssetLoader {
  _FakeAssetLoader(this.content);

  final String content;
  final List<String> requestedPaths = [];

  @override
  Future<String> readAsString(String assetPath) async {
    requestedPaths.add(assetPath);
    return content;
  }
}

void main() {
  group('MatchupMatrix', () {
    test('parses compact keyed JSON and calculates baseline win rates', () {
      final sampleJson = {
        '1': {
          '2': [40, 100],
          '3': [60, 100],
        },
        '2': {
          '1': [60, 100],
          '3': [50, 100],
        },
        '3': {
          '1': [40, 100],
          '2': [50, 100],
        },
      };

      final matrix = MatchupMatrix.fromJson(sampleJson);

      // Pairwise matchup checks
      final m1vs2 = matrix.getMatchup(1, 2);
      expect(m1vs2, isNotNull);
      expect(m1vs2!.wins, 40);
      expect(m1vs2.totalGames, 100);
      expect(m1vs2.winRate, 0.40);

      final m2vs1 = matrix.getMatchup(2, 1);
      expect(m2vs1, isNotNull);
      expect(m2vs1!.wins, 60);
      expect(m2vs1.totalGames, 100);
      expect(m2vs1.winRate, 0.60);

      // Baseline win rates:
      // Hero 1: (40 + 60) / (100 + 100) = 100 / 200 = 0.50
      expect(matrix.getBaseWinRate(1), 0.50);
      // Hero 2: (60 + 50) / (100 + 100) = 110 / 200 = 0.55
      expect(matrix.getBaseWinRate(2), 0.55);
      // Hero 3: (40 + 50) / (100 + 100) = 90 / 200 = 0.45
      expect(matrix.getBaseWinRate(3), 0.45);

      // Unknown hero defaults to 0.50
      expect(matrix.getBaseWinRate(999), 0.50);
      expect(matrix.getMatchup(1, 999), isNull);
    });

    test('successfully parses committed bundled hero_matchups.json asset', () {
      final file = File('assets/data/hero_matchups.json');
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final matrix = MatchupMatrix.fromJson(json);

      expect(matrix.matchups.length, greaterThan(120));
      // Verify Anti-Mage (ID: 1) has valid matchups and baseline win rate
      final amBasewin = matrix.getBaseWinRate(1);
      expect(amBasewin, greaterThan(0.3));
      expect(amBasewin, lessThan(0.7));
    });
  });

  group('SnapshotMatchupMatrixRepository', () {
    test('loads MatchupMatrix from SnapshotSource', () async {
      final sampleJson = {
        '1': {
          '2': [25, 50],
        },
      };

      final source = SnapshotSource(
        overrides: OverrideStore(InMemoryFileStore()),
        assets: _FakeAssetLoader(jsonEncode(sampleJson)),
      );
      final repo = SnapshotMatchupMatrixRepository(source);

      final matrix = await repo.loadMatchupMatrix();
      expect(matrix.getBaseWinRate(1), 0.50);
      expect(matrix.getMatchup(1, 2)?.wins, 25);
    });

    test('throws FormatException when JSON is invalid format', () async {
      final source = SnapshotSource(
        overrides: OverrideStore(InMemoryFileStore()),
        assets: _FakeAssetLoader('not-a-map'),
      );
      final repo = SnapshotMatchupMatrixRepository(source);

      expect(() => repo.loadMatchupMatrix(), throwsA(isA<FormatException>()));
    });
  });
}
