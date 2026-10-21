// Pins the snapshot tool's emitted app schema for Patches.
//
// This parses the REAL file `dart run tool/snapshot.dart` writes into bundled
// assets — never a hand-copied sample — so tool-side or Valve-side schema
// drift breaks CI loudly instead of crashing the app in the wild
// (spec: user story 43, "parsing tests consume real snapshot fixture files").

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';

const fixturePath = 'assets/data/patches.english.json';

void main() {
  Map<String, dynamic> decodeFixture() {
    final file = File(fixturePath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$fixturePath missing — run: dart run tool/snapshot.dart',
    );
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  test('bundled fixture carries the pinned top-level schema', () {
    final json = decodeFixture();

    expect(json['schema_version'], patchIndexSchemaVersion);
    expect(json['locale'], 'english');
    expect(json['patches'], isA<List<dynamic>>());
  });

  test('parses the real emitted patch index', () {
    final index = PatchIndex.fromJson(decodeFixture());

    expect(index.schemaVersion, patchIndexSchemaVersion);
    expect(index.locale, 'english');
    expect(index.patches.length, greaterThan(100));

    // Latest patch pinned at top (7.41f, verified live 2026-10-21)
    final latest = index.latestPatch;
    expect(latest, isNotNull);
    expect(latest!.patchNumber, '7.41f');
    expect(latest.patchName, '7.41f');
    expect(latest.timestamp, 1789455600);
    expect(latest.releaseDate, DateTime.utc(2026, 9, 15, 7));

    // Older patch exists
    final p708 = index.patches.firstWhere((p) => p.patchNumber == '7.08');
    expect(p708.timestamp, 1517472000);
  });
}
