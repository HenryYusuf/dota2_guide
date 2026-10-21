// Feed → app-schema converter seam (the second half of "one converter, two
// writers": `tool/snapshot.dart` bundles what this emits and the refresh
// unit re-emits it, so a refreshed override is byte-shape compatible with
// the bundled per-Hero file by construction).
//
// The synthetic feed lives in `synthetic_herodata_feed.dart` (shared with
// the refresh-unit test): it mirrors the live herodata feed's shape
// (verified 2026-10-21 against `herodata?language=english&hero_id=1`),
// trimmed to the fields the converter reads. Display strings replicate
// Valve's own decode tables extracted from dota2.com's front-end `main.js`,
// so the app shows what the official site shows.

import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_feed_to_detail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_herodata_feed.dart';

Map<String, Object?> convert({Map<String, Object?>? hero}) =>
    heroDetailFromFeed(feedDocument(hero ?? heroFeed()), locale: 'english');

List<Map<String, Object?>> abilitiesOf(Map<String, Object?> json) =>
    (json['abilities']! as List<Object?>).cast<Map<String, Object?>>();

void main() {
  group('hero block', () {
    test('maps identity, attributes, combat stats, and lore', () {
      final hero = convert()['hero']! as Map<String, Object?>;

      expect(hero['id'], 1);
      expect(hero['valve_key'], 'npc_dota_hero_antimage');
      expect(hero['localized_name'], 'Anti-Mage');
      expect(hero['one_liner'], 'Slashes his foes with mana-draining attacks');
      expect(hero['primary_attribute'], 'agility');
      expect(hero['complexity'], 1);
      expect(
        hero['portrait_url'],
        'https://cdn.steamstatic.com/apps/dota2/images/dota_react/heroes/'
        'antimage.png',
      );
      expect(hero['attributes'], {
        'strength': {'base': 21, 'gain': 1.6},
        'agility': {'base': 25, 'gain': 2.8},
        'intelligence': {'base': 12, 'gain': 1.8},
      });
      expect(hero['combat'], {
        'damage_min': 54,
        'damage_max': 58,
        'attack_rate': 1.4,
        'attack_range': 150,
        'projectile_speed': 0,
        // Truncated to two decimals, like the official site shows.
        'armor': 6.16,
        'magic_resistance': 25,
        'movement_speed': 315,
        'turn_rate': 0.6,
        'sight_range_day': 1800,
        'sight_range_night': 800,
      });
      expect(hero['bio'], 'A pilgrim survived the Dead God.');
    });

    test('wraps the document in the versioned envelope', () {
      final json = convert();

      expect(json['schema_version'], heroDetailSchemaVersion);
      expect(json['locale'], 'english');
      expect(json['hero'], isA<Map<String, Object?>>());
    });

    test('rejects an unknown primary attribute (feed drift)', () {
      final hero = heroFeed()..['primary_attr'] = 9;

      expect(() => convert(hero: hero), throwsFormatException);
    });
  });

  group('abilities', () {
    test('maps name, icon URL, and innate/ultimate markers', () {
      final list = abilitiesOf(convert());

      expect(list, hasLength(4));
      expect(list.first['name'], 'antimage_mana_break');
      expect(list.first['display_name'], 'Mana Break');
      expect(
        list.first['icon_url'],
        'https://cdn.steamstatic.com/apps/dota2/images/dota_react/abilities/'
        'antimage_mana_break.png',
      );
      expect(list.first['is_innate'], isFalse);
      expect(list[2]['is_innate'], isTrue);
      expect(list[2]['display_name'], 'Persecutor');
      expect(list[3]['is_ultimate'], isTrue);
    });

    test('decodes the behavior bitmask like the official front-end', () {
      final list = abilitiesOf(convert());

      // Bit 2 — passive wins over the target-type tags, as on dota2.com.
      expect(list[0]['behavior_tag'], 'Passive');
      // Point-target bit of 274878431248 (single tag: the chain stops at
      // the first match).
      expect(list[1]['behavior_tag'], 'Point Target');
      // 40 = Unit Target | Point AOE → the chain stops at Unit Target.
      expect(list[3]['behavior_tag'], 'Unit Target');
    });

    test('decodes targeting, immunity, damage, and dispel', () {
      final list = abilitiesOf(convert());

      // target_team 2 + target_type 19 (&7 == 3) — "Enemy Units".
      expect(list[3]['target'], 'Enemy Units');
      expect(list[3]['pierces_spell_immunity'], 'No');
      expect(list[3]['damage_type'], 'Magical');
      // dispellable 0 — no tag, field omitted.
      expect(list[3].containsKey('dispellable'), isFalse);
      // immunity 0 on Blink — field omitted.
      expect(list[1].containsKey('pierces_spell_immunity'), isFalse);
    });

    test('substitutes %tokens% in description, notes, and scepter text', () {
      final list = abilitiesOf(convert());

      expect(
        list[0]['description'],
        'Burns mana equal to 65% of the mana burnt as damage. Burns 25 mana '
        'per hit, up to 1.8% of max mana.',
      );
      expect(list[0]['notes'], ['25% mana burn from illusions.']);
      // The scepter text prefers values_scepter over the base value.
      expect(
        list[1]['scepter_text'],
        'After casting Blink, your next Mana Break burns an additional 20% '
        'max mana.',
      );
      expect(list[1].containsKey('shard_text'), isFalse);
    });

    test("emits per-level costs and the heading'd special-value table", () {
      final list = abilitiesOf(convert());

      expect(list[1]['cast_ranges'], [875, 950, 1025, 1100]);
      expect(list[1]['mana_costs'], [60, 55, 50, 45]);
      expect(list[1]['cooldowns'], [10.5, 9, 7.5, 6]);
      // Heading-less special values (illusion_percentage, AbilityCastRange…)
      // are tooltip plumbing, not table rows — dropped, like the site does.
      expect(list[0]['special_values'], [
        {
          'heading': 'MANA BURNED AS DAMAGE:',
          'values': [65],
          'is_percentage': false,
        },
        {
          'heading': 'MANA BURNED PER HIT:',
          'values': [25, 30, 35, 40],
          'is_percentage': false,
        },
        {
          'heading': 'MAX MANA BURNED PER HIT:',
          'values': [1.8, 2.7, 3.6, 4.5],
          'is_percentage': true,
        },
      ]);
    });
  });

  group('talents', () {
    test('resolves {s:…} tokens from own values and ability bonuses', () {
      final talents = (convert()['talents']! as List<Object?>).cast<String>();

      expect(talents, [
        '+3 Health Regen',
        '+200 Mana Void Radius',
        '+9%/18% Persecutor Min/Max Movement Slow',
        '+0.2 Mana Void Damage Multiplier',
        '+125 Blink Cast Range',
        '-1s Blink Cooldown',
        '+0.8s Mana Void Stun',
        '-50s Mana Void Cooldown',
      ]);
    });

    test('keeps feed order: pair (2i, 2i+1) is the level 10+5i tier', () {
      // Contract with the screen: talents[6], talents[7] are the level-25
      // pair, talents[0], talents[1] the level-10 pair (the official tree
      // renders talent i*2 on the right, i*2+1 on the left, top tier first).
      final talents = (convert()['talents']! as List<Object?>).cast<String>();

      expect(talents.first, '+3 Health Regen');
      expect(talents.last, '-50s Mana Void Cooldown');
    });
  });

  group('facets', () {
    test('a hero without facets gets an empty list (hidden when empty)', () {
      expect(convert()['facets'], isEmpty);
    });

    test('maps each facet with its granted and changed abilities', () {
      const facetName = 'antimage_magebanes_mirror';
      final granted = ability(
        name: 'antimage_mana_flare',
        nameLoc: 'Mana Flare',
        descLoc: 'Throws a flare burning %flare_burn_pct%%% mana.',
        specialValues: [
          specialValue('flare_burn_pct', valuesFloat: const [30]),
        ],
      );
      final changed = ability(
        name: 'antimage_counterspell',
        nameLoc: 'Counterspell',
        descLoc: 'Blocks and reflects targeted spells.',
        facetsLoc: const ['Burns mana when reflecting a spell.', ''],
        specialValues: [
          specialValue(
            'mana_burn_pct',
            valuesFloat: const [14],
            facetBonusName: facetName,
            facetBonusValues: const [25],
          ),
        ],
      );
      final hero = heroFeed(
        facets: [
          facet(facetName, titleLoc: "Magebane's Mirror")
            ..['description_loc'] =
                'Counterspell burns %bonus_mana_burn_pct%%% of the countered '
                "spell's mana cost.",
        ],
        abilities: [changed],
        talents: const [],
        facetAbilities: [
          {
            'abilities': [granted],
          },
        ],
      );

      final facets = (convert(hero: hero)['facets']! as List<Object?>)
          .cast<Map<String, Object?>>();

      expect(facets, hasLength(1));
      final facetJson = facets.single;
      expect(facetJson['title'], "Magebane's Mirror");
      expect(
        facetJson['description'],
        "Counterspell burns 25% of the countered spell's mana cost.",
      );
      expect(facetJson['granted'], [
        {
          'display_name': 'Mana Flare',
          'description': 'Throws a flare burning 30% mana.',
        },
      ]);
      expect(facetJson['changed'], [
        {
          'display_name': 'Counterspell',
          'description': 'Burns mana when reflecting a spell.',
        },
      ]);
    });
  });
}
