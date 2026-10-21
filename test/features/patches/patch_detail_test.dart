// Pins the snapshot tool's emitted app schema for Patch Detail.
//
// This parses the REAL file `dart run tool/snapshot.dart` writes into bundled
// assets — never a hand-copied sample — so tool-side or Valve-side schema
// drift breaks CI loudly instead of crashing the app in the wild
// (spec: user story 43, "parsing tests consume real snapshot fixture files").

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';

const fixturePath = 'assets/data/patch_7.41f.english.json';

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

    expect(json['schema_version'], patchDetailSchemaVersion);
    expect(json['locale'], 'english');
    expect(json['patch_number'], '7.41f');
    expect(json['sections'], isA<List<dynamic>>());
  });

  test('parses the real emitted patch detail', () {
    final detail = PatchDetail.fromJson(decodeFixture());

    expect(detail.schemaVersion, patchDetailSchemaVersion);
    expect(detail.locale, 'english');
    expect(detail.patchNumber, '7.41f');
    expect(detail.patchName, '7.41f');
    expect(detail.timestamp, 1789455600);
    expect(detail.sections, isNotEmpty);

    // Should have Items and Heroes sections
    final itemSection = detail.sections.firstWhere((s) => s.title == 'Items');
    expect(itemSection.groups, isNotEmpty);

    // E.g. Infused Raindrops (id 265)
    final raindrops = itemSection.groups.firstWhere((g) => g.itemId == 265);
    expect(raindrops.title, 'Infused Raindrops');
    expect(raindrops.iconUrl, contains('infused_raindrop.png'));
    expect(raindrops.lines, isNotEmpty);
    expect(raindrops.lines.first.indentLevel, 1);

    final heroSection = detail.sections.firstWhere((s) => s.title == 'Heroes');
    expect(heroSection.groups, isNotEmpty);

    // E.g. Anti-Mage (id 1)
    final antimage = heroSection.groups.firstWhere((g) => g.heroId == 1);
    expect(antimage.title, 'Anti-Mage');
    expect(antimage.iconUrl, contains('antimage.png'));
    expect(antimage.lines, isNotEmpty);
  });
}
