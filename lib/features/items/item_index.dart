/// Item index: the app schema for the bundled Item snapshot.
///
/// The contract is the FILE, not this class: `dart run tool/snapshot.dart`
/// emits `assets/data/items.<locale>.json` and
/// `test/features/items/item_index_test.dart` parses that real file to pin
/// the schema. Parsing is strict — anything unrecognised throws
/// [FormatException] so drift surfaces in CI instead of rendering garbage.
///
/// The index is the whole Item catalogue (all 544 entries the feed serves,
/// including recipe prices and retired Items): the Items tab filters what it
/// shows, and later tickets (patch notes) need to resolve ANY Item id.
library;

import 'shop_categories.dart';

/// Current schema version of the emitted item-index file.
const int itemIndexSchemaVersion = 1;

/// Parsed content of one bundled item-index file.
class ItemIndex {
  const ItemIndex({
    required this.schemaVersion,
    required this.locale,
    required this.items,
  });

  factory ItemIndex.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != itemIndexSchemaVersion) {
      throw FormatException(
        'Unsupported item-index schema_version $schemaVersion '
        '(app expects $itemIndexSchemaVersion)',
      );
    }
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Item index: "items" missing or not a list');
    }
    return ItemIndex(
      schemaVersion: schemaVersion,
      locale: _requiredString(json, 'locale'),
      items: rawItems
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw FormatException('Item entry is not an object: $raw');
            }
            return ItemSummary.fromJson(raw);
          })
          .toList(growable: false),
    );
  }

  final int schemaVersion;

  /// Valve feed language token the names were snapshotted in.
  final String locale;

  /// Every Item in feed order. Grouping, filtering, and sorting for display
  /// are the screen's business.
  final List<ItemSummary> items;
}

/// One Item as the Items tab needs it: identity, the shop tab it presents
/// under, the neutral tier (when it is a neutral Item), and the Valve CDN
/// icon URL (streamed at runtime, never bundled — ADR-0001).
class ItemSummary {
  const ItemSummary({
    required this.id,
    required this.valveKey,
    required this.name,
    required this.shopCategory,
    required this.neutralTier,
    required this.isRecipe,
    required this.iconUrl,
  });

  factory ItemSummary.fromJson(Map<String, dynamic> json) {
    final neutralTier = json['neutral_tier'];
    if (neutralTier != null && (neutralTier is! int || neutralTier < 0)) {
      throw FormatException(
        'Item neutral_tier must be null or >= 0: '
        '$neutralTier',
      );
    }
    final shopCategory = ShopCategory.parse(
      _requiredString(json, 'shop_category'),
    );
    final valveKey = _requiredString(json, 'valve_key');
    final isRecipe = _requiredBool(json, 'is_recipe');
    if (isRecipe != isRecipeItemKey(valveKey)) {
      throw FormatException(
        'Item $valveKey: is_recipe disagrees with the Valve key prefix',
      );
    }
    return ItemSummary(
      id: _requiredInt(json, 'id'),
      valveKey: valveKey,
      // A feed name may legitimately be empty: 37 internal entries (recipe
      // prices, disabled Items) ship no localized name. The Items tab hides
      // them; the schema keeps them so any Item id stays resolvable.
      name: json['name'] as String? ?? '',
      shopCategory: shopCategory,
      neutralTier: neutralTier as int?,
      isRecipe: isRecipe,
      iconUrl: _requiredString(json, 'icon_url'),
    );
  }

  /// Valve's numeric item id (stable across locales); what per-Item detail
  /// files are keyed by.
  final int id;

  /// Valve key name, e.g. `item_blink`; also derives the CDN icon file name.
  final String valveKey;

  /// Display name in the snapshot's locale; empty for internal entries.
  /// What name search matches against.
  final String name;

  /// The shop tab this Item is grouped under.
  final ShopCategory shopCategory;

  /// 0-based neutral tier (0 … 4), or null when the Item is not neutral.
  /// Display as `neutralTierLabel(tier)`.
  final int? neutralTier;

  /// True for recipe-price entries (`item_recipe_*`): they exist so a build's
  /// combination cost is knowable, and are never shop rows.
  final bool isRecipe;

  /// Absolute Valve CDN URL for the 64×64 icon; loaded at runtime.
  final String iconUrl;

  /// Whether the Items tab should list this Item (named, not a recipe price).
  bool get isListable => !isRecipe && name.isNotEmpty;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Item index: "$key" missing or not an int');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Item index: "$key" missing or not a bool');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Item index: "$key" missing or empty');
  }
  return value;
}
