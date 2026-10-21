// Schema seam: the emitted per-Item file is the contract. This test parses
// the REAL fixture `assets/data/item_1.english.json` (written by
// `dart run tool/snapshot.dart`) and pins every section the detail screen
// reads, plus a sweep over all bundled Item files — so schema drift fails
// here instead of rendering garbage offline.

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readFixture(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('Blink Dagger fixture (item_1.english.json)', () {
    late ItemDetail detail;

    setUpAll(() {
      detail = ItemDetail.fromJson(_readFixture(itemDetailAssetPath(1)));
    });

    test('parses identity, cost, effects, notes, and lore', () {
      expect(detail.schemaVersion, itemDetailSchemaVersion);
      expect(detail.locale, 'english');

      final item = detail.item;
      expect(item.id, 1);
      expect(item.valveKey, 'item_blink');
      expect(item.name, 'Blink Dagger');
      expect(item.iconUrl, endsWith('/dota_react/items/blink.png'));
      expect(item.shopCategory, ShopCategory.caster);
      expect(item.neutralTier, isNull);
      expect(item.totalCost, 2250);
      expect(item.combinationCost, isNull);
      expect(item.components, isEmpty);

      expect(item.effects, hasLength(1));
      final effect = item.effects.first;
      expect(effect.kind, ItemEffectKind.active);
      expect(effect.title, 'Blink');
      expect(effect.text, contains('Teleport to a target point'));

      expect(item.notes, hasLength(1));
      expect(item.notes.first, contains('Self-casting'));

      expect(item.lore, startsWith('The fabled dagger'));
    });
  });

  group('Eul\'s Scepter fixture (item_100.english.json)', () {
    late ItemDetail detail;

    setUpAll(() {
      detail = ItemDetail.fromJson(_readFixture(itemDetailAssetPath(100)));
    });

    test('parses combination cost, components, and attributes', () {
      final item = detail.item;
      expect(item.id, 100);
      expect(item.name, 'Eul\'s Scepter of Divinity');
      expect(item.totalCost, 2600);
      expect(item.combinationCost, 675);
      expect(item.components, [23, 57, 244]);

      expect(item.attributes, isNotEmpty);
      final intAttr = item.attributes.firstWhere(
        (a) => a.label == 'Intelligence',
      );
      expect(intAttr.sign, '+');
      expect(intAttr.values, [10]);
      expect(intAttr.display, '+10 Intelligence');
    });
  });

  test('every bundled Item detail file parses without error', () {
    final dir = Directory('assets/data');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'item_\d+\.english\.json$').hasMatch(f.path))
        .toList();

    expect(files.length, greaterThan(350));

    for (final file in files) {
      final detail = ItemDetail.fromJson(_readFixture(file.path));
      expect(detail.item.id, greaterThan(0));
      expect(detail.item.name, isNotEmpty);
      expect(detail.item.totalCost, greaterThanOrEqualTo(0));
      if (detail.item.combinationCost case final int cost) {
        expect(cost, greaterThan(0));
      }
    }
  });
}
