import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patch_feed_to_detail.dart';

void main() {
  group('patchDetailFromFeed', () {
    test('converts feed JSON into structured sections with resolved entity names and icons', () {
      final feed = {
        'patch_number': '7.41f',
        'patch_name': '7.41f',
        'patch_timestamp': 1789455600,
        'general_notes': [
          {
            'title': 'General Changes',
            'generic': [
              {
                'indent_level': 1,
                'note':
                    'Courier respawn time <font color="#fff">decreased</font>',
              },
              {'indent_level': 1, 'hide_dot': true, 'note': '<br>'},
            ],
          },
        ],
        'items': [
          {
            'ability_id': 265,
            'ability_notes': [
              {
                'indent_level': 1,
                'note': 'Mana Regen bonus decreased from +0.8 to +0.6',
              },
            ],
          },
        ],
        'neutral_items': [
          {
            'ability_id': -1,
            'title': 'Enchantment Changes',
            'is_general_note': true,
          },
        ],
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
                  {
                    'indent_level': 2,
                    'note': 'Aghanim Scepter upgrade bonus increased',
                    'aghanims': 'scepter',
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
        ],
        'success': true,
      };

      final json = patchDetailFromFeed(
        feed,
        locale: 'english',
        heroNameLookup: (id) => id == 1 ? 'Anti-Mage' : null,
        heroPortraitUrlLookup: (id) =>
            id == 1 ? 'https://cdn.steamstatic.com/antimage.png' : null,
        itemNameLookup: (id) => id == 265 ? 'Infused Raindrops' : null,
        itemIconUrlLookup: (id) => id == 265
            ? 'https://cdn.steamstatic.com/infused_raindrop.png'
            : null,
      );

      expect(json['schema_version'], patchDetailSchemaVersion);
      expect(json['locale'], 'english');
      expect(json['patch_number'], '7.41f');
      expect(json['patch_name'], '7.41f');
      expect(json['timestamp'], 1789455600);

      final detail = PatchDetail.fromJson(json);
      expect(detail.patchNumber, '7.41f');
      expect(detail.sections.length, 4);

      // Section 1: General
      final general = detail.sections[0];
      expect(general.title, 'General');
      expect(general.groups.length, 1);
      expect(general.groups[0].title, 'General Changes');
      expect(general.groups[0].lines.length, 1);
      expect(general.groups[0].lines[0].text, 'Courier respawn time decreased');

      // Section 2: Items
      final items = detail.sections[1];
      expect(items.title, 'Items');
      expect(items.groups.length, 1);
      final itemGroup = items.groups[0];
      expect(itemGroup.title, 'Infused Raindrops');
      expect(itemGroup.itemId, 265);
      expect(
        itemGroup.iconUrl,
        'https://cdn.steamstatic.com/infused_raindrop.png',
      );
      expect(itemGroup.lines.length, 1);
      expect(
        itemGroup.lines[0].text,
        'Mana Regen bonus decreased from +0.8 to +0.6',
      );

      // Section 3: Neutral Items
      final neutrals = detail.sections[2];
      expect(neutrals.title, 'Neutral Items');
      expect(neutrals.groups.length, 1);
      expect(neutrals.groups[0].title, 'Enchantment Changes');

      // Section 4: Heroes
      final heroes = detail.sections[3];
      expect(heroes.title, 'Heroes');
      expect(heroes.groups.length, 1);
      final am = heroes.groups[0];
      expect(am.title, 'Anti-Mage');
      expect(am.heroId, 1);
      expect(am.iconUrl, 'https://cdn.steamstatic.com/antimage.png');
      expect(am.lines.length, 4);
      expect(am.lines[0].text, 'Base Armor decreased by 1');
      expect(am.lines[0].indentLevel, 1);
      expect(
        am.lines[1].text,
        'Mana Burned as Damage increased from 60% to 65%',
      );
      expect(am.lines[2].indentLevel, 2);
      expect(am.lines[2].badge, 'scepter');
      expect(am.lines[3].text, 'Level 15 Talent Mana Void Cooldown reduced');
    });
  });
}
