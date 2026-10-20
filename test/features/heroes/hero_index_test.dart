// Pins the snapshot tool's emitted app schema.
//
// This parses the REAL file `dart run tool/snapshot.dart` writes into bundled
// assets — never a hand-copied sample — so tool-side or Valve-side schema
// drift breaks CI loudly instead of crashing the app in the wild
// (spec: user story 43, "parsing tests consume real snapshot fixture files").

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// Path of the bundled English hero index, relative to the package root.
const fixturePath = 'assets/data/heroes.english.json';

/// CDN portrait prefix, pinned as a literal so a wrong path convention in the
/// tool cannot agree with itself in here (no shared constant with the code
/// under test — verified live 2026-10-20).
const portraitPrefix =
    'https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/';

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

    expect(json['schema_version'], 1);
    expect(json['locale'], 'english');
    expect(json['heroes'], isA<List<dynamic>>());
  });

  test('parses the real emitted roster', () {
    final index = HeroIndex.fromJson(decodeFixture());

    expect(index.schemaVersion, 1);
    expect(index.locale, 'english');
    expect(index.heroes.length, greaterThan(100));

    // Known-good literals from the live feed (verified 2026-10-20): the first
    // hero in the roster is Anti-Mage, id 1.
    final antiMage = index.heroes.first;
    expect(antiMage.id, 1);
    expect(antiMage.valveKey, 'npc_dota_hero_antimage');
    expect(antiMage.localizedName, 'Anti-Mage');
    expect(antiMage.primaryAttribute, PrimaryAttribute.agility);
    expect(antiMage.complexity, 1);
    expect(antiMage.portraitUrl, '${portraitPrefix}antimage.png');
  });

  test('every emitted hero parses into a consistent shape', () {
    final index = HeroIndex.fromJson(decodeFixture());

    final seenIds = <int>{};
    for (final hero in index.heroes) {
      expect(hero.id, greaterThan(0));
      expect(seenIds.add(hero.id), isTrue, reason: 'duplicate id ${hero.id}');
      expect(hero.valveKey, startsWith('npc_dota_hero_'));
      expect(hero.localizedName, isNotEmpty);
      expect(hero.primaryAttribute, isA<PrimaryAttribute>());
      expect(hero.complexity, inInclusiveRange(1, 3));
      expect(hero.portraitUrl, startsWith(portraitPrefix));
      expect(hero.portraitUrl, endsWith('.png'));
      expect(
        hero.portraitUrl,
        '$portraitPrefix${hero.valveKey.replaceFirst('npc_dota_hero_', '')}.png',
      );
    }
  });

  test('rejects an unknown schema version (schema drift)', () {
    final json = decodeFixture()..['schema_version'] = 2;

    expect(() => HeroIndex.fromJson(json), throwsFormatException);
  });

  test('rejects an unknown primary attribute (feed drift)', () {
    final json = decodeFixture();
    (json['heroes'] as List<dynamic>).first['primary_attribute'] = 'strengths';

    expect(() => HeroIndex.fromJson(json), throwsFormatException);
  });

  test('rejects an out-of-range complexity (feed drift)', () {
    final json = decodeFixture();
    (json['heroes'] as List<dynamic>).first['complexity'] = 4;

    expect(() => HeroIndex.fromJson(json), throwsFormatException);
  });

  test('rejects a hero missing a required field (feed drift)', () {
    final json = decodeFixture();
    (json['heroes'] as List<dynamic>).first.remove('portrait_url');

    expect(() => HeroIndex.fromJson(json), throwsFormatException);
  });
}
