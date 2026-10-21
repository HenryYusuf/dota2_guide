// Schema seam: the emitted per-Hero file is the contract. This test parses
// the REAL fixture `assets/data/hero_1.english.json` (written by
// `dart run tool/snapshot.dart`) and pins every section the detail screen
// reads, plus a sweep over all bundled Hero files — so schema drift fails
// here instead of rendering garbage offline.

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads a bundled snapshot file straight from disk: the same bytes the app
/// loads through the asset bundle, without needing a Flutter binding.
Map<String, dynamic> _readFixture(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('Anti-Mage fixture (hero_1.english.json)', () {
    late HeroDetail detail;

    setUpAll(() {
      detail = HeroDetail.fromJson(_readFixture(heroDetailAssetPath(1)));
    });

    test('parses the header: identity, attributes, combat, lore', () {
      expect(detail.schemaVersion, heroDetailSchemaVersion);
      expect(detail.locale, 'english');

      final hero = detail.hero;
      expect(hero.id, 1);
      expect(hero.valveKey, 'npc_dota_hero_antimage');
      expect(hero.localizedName, 'Anti-Mage');
      expect(hero.oneLiner, 'Slashes his foes with mana-draining attacks');
      expect(hero.primaryAttribute, PrimaryAttribute.agility);
      expect(hero.complexity, 1);
      expect(hero.portraitUrl, endsWith('/dota_react/heroes/antimage.png'));

      expect(hero.attributes.agility.base, 25);
      expect(hero.attributes.agility.gain, 2.8);
      expect(hero.attributes.strength.base, 21);
      expect(hero.attributes.strength.gain, 1.6);
      expect(hero.attributes.intelligence.base, 12);
      expect(hero.attributes.intelligence.gain, 1.8);

      final combat = hero.combat;
      expect(combat.damageMin, 54);
      expect(combat.damageMax, 58);
      expect(combat.attackRate, 1.4);
      expect(combat.attackRange, 150);
      expect(combat.armor, closeTo(6.16, 0.001));
      expect(combat.magicResistance, 25);
      expect(combat.movementSpeed, 315);
      expect(combat.sightRangeNight, 800);

      expect(hero.bio, startsWith('The monks of Turstarkuri'));
    });

    test('parses abilities with decoded behaviour, costs, and table rows', () {
      expect(detail.abilities, hasLength(5));

      final blink = detail.abilities.singleWhere(
        (ability) => ability.name == 'antimage_blink',
      );
      expect(blink.displayName, 'Blink');
      expect(
        blink.iconUrl,
        endsWith('/dota_react/abilities/antimage_blink.png'),
      );
      expect(blink.behaviorTag, 'Point Target');
      expect(blink.piercesSpellImmunity, isNull); // "none" decodes to null
      expect(blink.isInnate, isFalse);
      expect(blink.isUltimate, isFalse);
      expect(blink.castRanges, [875, 950, 1025, 1100]);
      expect(blink.manaCosts, [60, 55, 50, 45]);
      expect(blink.cooldowns, [10.5, 9, 7.5, 6]);
      expect(blink.specialValues, hasLength(1));
      expect(blink.specialValues.single.heading, 'DEBUFF DURATION:');
      // Per-level values survive conversion, one entry per Ability level.
      expect(blink.specialValues.single.values, [0]);
      final manaBreak = detail.abilities.singleWhere(
        (ability) => ability.name == 'antimage_mana_break',
      );
      final perHit = manaBreak.specialValues.singleWhere(
        (special) => special.heading == 'MANA BURNED PER HIT:',
      );
      expect(perHit.values, [25, 30, 35, 40]);
      expect(perHit.isPercentage, isFalse);
      expect(blink.scepterText, contains('mana'));
      expect(blink.shardText, isNull);
      // Texts are resolved at conversion time: no raw tokens survive.
      expect(blink.description, isNot(contains('%')));
      expect(blink.description, isNot(contains('{s:')));
    });

    test('marks the innate ability and the ultimate distinctly', () {
      final innate = detail.abilities.singleWhere(
        (ability) => ability.isInnate,
      );
      expect(innate.name, 'antimage_persectur');
      expect(innate.displayName, 'Persecutor');
      expect(innate.specialValues, hasLength(3));
      expect(innate.specialValues.first.heading, 'MIN MOVEMENT SLOW:');
      expect(innate.specialValues.first.isPercentage, isTrue);

      final ultimate = detail.abilities.singleWhere(
        (ability) => ability.isUltimate,
      );
      expect(ultimate.name, 'antimage_mana_void');

      expect(
        detail.abilities.where((ability) => ability.grantedBy != null),
        isEmpty, // Anti-Mage has no ability that only exists via Aghanim's
      );
    });

    test('parses eight resolved talents in feed order', () {
      expect(detail.talents, hasLength(8));
      expect(detail.talents.first, '+3 Health Regen');
      expect(detail.talents[1], '+200 Mana Void Radius');
      expect(detail.talents.last, '-50s Mana Void Cooldown');
      expect(detail.talents.every((talent) => talent.isNotEmpty), isTrue);
    });

    test('parses facets as an empty list on current data', () {
      // Patch 7.41 removed Facets; the pipeline still parses them (covered by
      // the converter test) and the screen hides the section when empty.
      expect(detail.facets, isEmpty);
    });
  });

  group('bundled fixture sweep', () {
    test('every emitted hero_<id> file parses and matches its file name', () {
      final files = Directory('assets/data')
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                RegExp(r'hero_\d+\.english\.json')
                    .hasMatch(file.uri.pathSegments.last),
          )
          .toList(growable: false);
      expect(files, hasLength(127), reason: 'full roster snapshot expected');

      final index = _readFixture('assets/data/heroes.english.json');
      final rosterIds = (index['heroes'] as List)
          .map((hero) => (hero as Map<String, dynamic>)['id'] as int)
          .toSet();

      for (final file in files) {
        final name = file.uri.pathSegments.last;
        final id = int.parse(
          RegExp(r'hero_(\d+)\.english\.json').firstMatch(name)!.group(1)!,
        );
        final detail = HeroDetail.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
        );
        expect(detail.hero.id, id, reason: '$name: id must match its name');
        expect(rosterIds, contains(id), reason: '$name: not in the roster');
        expect(detail.talents, hasLength(8), reason: name);
        expect(
          detail.abilities.any((ability) => ability.isInnate) ||
              detail.abilities.isEmpty,
          isTrue,
          reason: name,
        );
      }
    });
  });

  group('drift rejection', () {
    Map<String, dynamic> minimal() => _readFixture(heroDetailAssetPath(1));

    test('an unknown schema_version throws instead of rendering garbage', () {
      final json = minimal()..['schema_version'] = 2;

      expect(
        () => HeroDetail.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('schema_version'),
          ),
        ),
      );
    });

    test('a missing required hero field throws', () {
      final json = minimal();
      (json['hero'] as Map<String, dynamic>).remove('localized_name');

      expect(() => HeroDetail.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('an unknown granted_by value throws', () {
      final json = minimal();
      ((json['abilities'] as List).first
              as Map<String, dynamic>)['granted_by'] =
          'moonshard';

      expect(
        () => HeroDetail.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('granted_by'),
          ),
        ),
      );
    });

    test('a complexity outside 1-3 throws', () {
      final json = minimal();
      (json['hero'] as Map<String, dynamic>)['complexity'] = 4;

      expect(() => HeroDetail.fromJson(json), throwsA(isA<FormatException>()));
    });
  });

  group('unit naming', () {
    test('the override unit and the bundled asset share one base name', () {
      expect(heroDetailUnitName(1), 'hero_1.english.json');
      expect(heroDetailAssetPath(1), 'assets/data/hero_1.english.json');
      expect(heroDetailAssetPath(42), 'assets/data/${heroDetailUnitName(42)}');
    });

    test('the locale lives in the file name (future UI languages)', () {
      expect(heroDetailUnitName(1, locale: 'russian'), 'hero_1.russian.json');
      expect(
        heroDetailAssetPath(1, locale: 'russian'),
        'assets/data/hero_1.russian.json',
      );
    });
  });
}
