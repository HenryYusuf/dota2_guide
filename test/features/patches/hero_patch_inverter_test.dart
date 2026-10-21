import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/patches/hero_patch_inverter.dart';

void main() {
  group('invertPatchHistory', () {
    test('inverts raw patch notes across multiple patches by hero ID', () {
      final patch741e = {
        'patch_number': '7.41e',
        'patch_name': '7.41e',
        'patch_timestamp': 1785394800,
        'heroes': [
          {
            'hero_id': 1,
            'hero_notes': [
              {
                'indent_level': 1,
                'note': 'Base Strength increased from 20 to 21',
              },
            ],
            'abilities': [
              {
                'ability_id': 5004,
                'ability_notes': [
                  {
                    'indent_level': 1,
                    'note': 'Blink range <font color="#fff">increased</font> from 750/900/1050/1200 to 800/950/1100/1250',
                  },
                ],
              },
            ],
            'talent_notes': <Map<String, dynamic>>[],
          },
        ],
      };

      final patch741f = {
        'patch_number': '7.41f',
        'patch_name': '7.41f',
        'patch_timestamp': 1789455600,
        'heroes': [
          {
            'hero_id': 1,
            'hero_notes': [
              {'indent_level': 1, 'note': 'Base Armor decreased by 1'},
            ],
            'abilities': [
              {
                'ability_id': 5003,
                'ability_notes': [
                  {
                    'indent_level': 1,
                    'note': 'Mana Burned as Damage increased from 60% to 65%',
                  },
                ],
              },
            ],
            'talent_notes': [
              {
                'indent_level': 1,
                'note': 'Level 15 Talent Mana Void Cooldown reduced',
              },
            ],
          },
          {
            'hero_id': 2,
            'hero_notes': [
              {
                'indent_level': 1,
                'note': 'Movement speed increased from 310 to 315',
              },
            ],
          },
        ],
      };

      final heroAbilityMap = {
        1: {5003: 'antimage_mana_break', 5004: 'antimage_blink'},
      };

      final result = invertPatchHistory(
        rawPatchFeeds: [patch741f, patch741e],
        heroAbilityMap: heroAbilityMap,
        locale: 'english',
      );

      expect(result['schema_version'], 1);
      expect(result['locale'], 'english');
      final heroes = result['heroes'] as Map<String, dynamic>;
      expect(heroes.containsKey('1'), isTrue);
      expect(heroes.containsKey('2'), isTrue);

      final am = heroes['1'] as Map<String, dynamic>;
      expect(am['hero_id'], 1);
      final deltas = am['deltas'] as List<dynamic>;
      expect(deltas.length, 2);

      // Newest patch (7.41f) first
      final delta741f = deltas[0] as Map<String, dynamic>;
      expect(delta741f['patch_number'], '7.41f');
      expect(delta741f['timestamp'], 1789455600);

      final stats741f = delta741f['stats'] as List<dynamic>;
      expect(stats741f.length, 1);
      expect(stats741f[0]['text'], 'Base Armor decreased by 1');

      final talents741f = delta741f['talents'] as List<dynamic>;
      expect(talents741f.length, 1);
      expect(
        talents741f[0]['text'],
        'Level 15 Talent Mana Void Cooldown reduced',
      );

      final abilities741f = delta741f['abilities'] as List<dynamic>;
      expect(abilities741f.length, 1);
      final manaBreakDelta = abilities741f[0] as Map<String, dynamic>;
      expect(manaBreakDelta['ability_id'], 5003);
      expect(manaBreakDelta['ability_name'], 'antimage_mana_break');
      final mbLines = manaBreakDelta['lines'] as List<dynamic>;
      expect(
        mbLines[0]['text'],
        'Mana Burned as Damage increased from 60% to 65%',
      );

      // Older patch (7.41e)
      final delta741e = deltas[1] as Map<String, dynamic>;
      expect(delta741e['patch_number'], '7.41e');
      final abilities741e = delta741e['abilities'] as List<dynamic>;
      expect(abilities741e.length, 1);
      final blinkDelta = abilities741e[0] as Map<String, dynamic>;
      expect(blinkDelta['ability_id'], 5004);
      expect(blinkDelta['ability_name'], 'antimage_blink');
      final blinkLines = blinkDelta['lines'] as List<dynamic>;
      // HTML stripped
      expect(
        blinkLines[0]['text'],
        'Blink range increased from 750/900/1050/1200 to 800/950/1100/1250',
      );
    });
  });
}
