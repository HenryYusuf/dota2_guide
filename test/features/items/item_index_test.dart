// Pins the snapshot tool's emitted app schema for Items.
//
// This parses the REAL file `dart run tool/snapshot.dart` writes into bundled
// assets — never a hand-copied sample — so tool-side or Valve-side schema
// drift breaks CI loudly instead of crashing the app in the wild
// (spec: user story 43, "parsing tests consume real snapshot fixture files").

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/features/items/item_index.dart';
import 'package:dota2_guide/features/items/shop_categories.dart';
import 'package:flutter_test/flutter_test.dart';

/// Path of the bundled English item index, relative to the package root.
const fixturePath = 'assets/data/items.english.json';

/// CDN icon prefix, pinned as a literal so a wrong path convention in the
/// tool cannot agree with itself in here.
const iconPrefix =
    'https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/';

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

    expect(json['schema_version'], itemIndexSchemaVersion);
    expect(json['locale'], 'english');
    expect(json['items'], isA<List<dynamic>>());
  });

  test('parses the real emitted item catalogue', () {
    final index = ItemIndex.fromJson(decodeFixture());

    expect(index.schemaVersion, itemIndexSchemaVersion);
    expect(index.locale, 'english');
    expect(index.items.length, greaterThan(500));

    // Known-good literals from the live feed (verified 2026-10-21):
    // item_blink is id 1.
    final blink = index.items.firstWhere((i) => i.id == 1);
    expect(blink.valveKey, 'item_blink');
    expect(blink.name, 'Blink Dagger');
    expect(blink.shopCategory, ShopCategory.caster);
    expect(blink.neutralTier, isNull);
    expect(blink.isRecipe, isFalse);
    expect(blink.iconUrl, '${iconPrefix}blink.png');
    expect(blink.isListable, isTrue);
  });

  test('every emitted item parses into a consistent shape', () {
    final index = ItemIndex.fromJson(decodeFixture());

    for (final item in index.items) {
      expect(item.id, greaterThan(0));
      expect(item.valveKey, isNotEmpty);
      expect(item.iconUrl, startsWith(iconPrefix));
      expect(item.iconUrl, endsWith('.png'));
      if (item.neutralTier case final int tier) {
        expect(tier, inInclusiveRange(0, 4));
      }
    }
  });

  test('neutral items cover all five tiers (0 to 4)', () {
    final index = ItemIndex.fromJson(decodeFixture());
    final tiers = index.items
        .where((i) => i.neutralTier != null)
        .map((i) => i.neutralTier!)
        .toSet();

    expect(tiers, equals({0, 1, 2, 3, 4}));
  });
}
