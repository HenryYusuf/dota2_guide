/// Item detail: the app schema for one per-Item detail file.
///
/// The contract is the FILE, not this class: `dart run tool/snapshot.dart`
/// emits `assets/data/item_<id>.<locale>.json` and
/// `test/features/items/item_detail_test.dart` parses that real file to pin
/// the schema. Parsing is strict — anything unrecognised throws
/// [FormatException] so drift surfaces in CI instead of rendering garbage.
///
/// All texts are already resolved: `%token%` substitutions from the feed's
/// special values and the `<h1>` section split happened at conversion time
/// (one converter, `item_feed_to_detail.dart`), so the app renders plain
/// strings.
library;

import 'shop_categories.dart';

/// Current schema version of the emitted per-Item detail files.
const int itemDetailSchemaVersion = 1;

/// The override-store unit for one Item's detail: same base name as the
/// bundled asset, so a refreshed file is the same document, one generation
/// newer. Lives here (pure Dart) so the snapshot tool can emit the same
/// names without importing the repository (Riverpod ≠ `dart run`-able).
///
/// The id and locale live in the file name so future UI languages are one
/// more snapshot file per Item, not a code change; the app reads the English
/// ones (v1 is English-only, per spec).
String itemDetailUnitName(int itemId, {String locale = 'english'}) =>
    'item_$itemId.$locale.json';

/// Bundled asset path for one Item's detail file (the app bundles English).
String itemDetailAssetPath(int itemId, {String locale = 'english'}) =>
    'assets/data/${itemDetailUnitName(itemId, locale: locale)}';

/// One Item's complete offline reference page, as bundled per Item id.
class ItemDetail {
  const ItemDetail({
    required this.schemaVersion,
    required this.locale,
    required this.item,
  });

  factory ItemDetail.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != itemDetailSchemaVersion) {
      throw FormatException(
        'Unsupported item-detail schema_version $schemaVersion '
        '(app expects $itemDetailSchemaVersion)',
      );
    }
    return ItemDetail(
      schemaVersion: schemaVersion,
      locale: _requiredString(json, 'locale'),
      item: ItemProfile.fromJson(_requiredObject(json, 'item')),
    );
  }

  final int schemaVersion;

  /// Valve feed language token the texts were snapshotted in.
  final String locale;

  /// Identity, costs, attributes, effects, notes, and lore.
  final ItemProfile item;
}

/// One Item as its detail page needs it.
class ItemProfile {
  const ItemProfile({
    required this.id,
    required this.valveKey,
    required this.name,
    required this.iconUrl,
    required this.shopCategory,
    required this.neutralTier,
    required this.totalCost,
    required this.combinationCost,
    required this.components,
    required this.attributes,
    required this.effects,
    required this.notes,
    required this.lore,
  });

  factory ItemProfile.fromJson(Map<String, dynamic> json) {
    final neutralTier = json['neutral_tier'];
    if (neutralTier != null && (neutralTier is! int || neutralTier < 0)) {
      throw FormatException(
        'Item detail: neutral_tier must be null or >= 0 ($neutralTier)',
      );
    }
    final totalCost = _requiredInt(json, 'total_cost');
    if (totalCost < 0) {
      throw FormatException('Item detail: negative total_cost ($totalCost)');
    }
    final combinationCost = json['combination_cost'];
    if (combinationCost != null &&
        (combinationCost is! int || combinationCost < 0)) {
      throw FormatException(
        'Item detail: combination_cost must be null or >= 0 '
        '($combinationCost)',
      );
    }
    return ItemProfile(
      id: _requiredInt(json, 'id'),
      valveKey: _requiredString(json, 'valve_key'),
      name: json['name'] as String? ?? '',
      iconUrl: _requiredString(json, 'icon_url'),
      shopCategory: ShopCategory.parse(_requiredString(json, 'shop_category')),
      neutralTier: neutralTier as int?,
      totalCost: totalCost,
      combinationCost: combinationCost as int?,
      components: _intList(json, 'components'),
      attributes: _objectList(
        json,
        'attributes',
      ).map(ItemAttribute.fromJson).toList(growable: false),
      effects: _objectList(
        json,
        'effects',
      ).map(ItemEffect.fromJson).toList(growable: false),
      notes: _optionalStringList(json, 'notes'),
      lore: json['lore'] as String? ?? '',
    );
  }

  final int id;

  /// Valve key name, e.g. `item_blink`; also derives the CDN icon file name.
  final String valveKey;

  /// Display name in the snapshot's locale; empty for internal entries.
  final String name;

  /// Absolute Valve CDN URL for the 64×64 icon; streamed at runtime.
  final String iconUrl;

  final ShopCategory shopCategory;

  /// 0-based neutral tier, or null when the Item is not neutral.
  final int? neutralTier;

  /// What the Item costs in total (`item_cost` in the feed).
  final int totalCost;

  /// What the build's recipe step costs — the paired `item_recipe_*` entry's
  /// own price. Null when the Item has no recipe step or that step is free
  /// (40 of the 129 recipe entries in the live feed cost 0), so the UI never
  /// renders a meaningless "0 gold" combination row.
  final int? combinationCost;

  /// The recipe step's component Item ids, in the feed's order — the data
  /// issue 07's Recipe tree renders (this page keeps costs only).
  final List<int> components;

  /// The stat rows ("+10 Strength"): heading'd special values, decoded.
  final List<ItemAttribute> attributes;

  /// Active / Passive / Toggle / Use sections split out of the description.
  final List<ItemEffect> effects;

  /// The free-text notes (`notes_loc`).
  final List<String> notes;

  /// The flavor text (`lore_loc`); empty when the Item has none.
  final String lore;
}

/// One stat row of the detail page's Attributes card.
class ItemAttribute {
  const ItemAttribute({
    required this.sign,
    required this.label,
    required this.values,
    required this.isPercentage,
  });

  factory ItemAttribute.fromJson(Map<String, dynamic> json) {
    final sign = json['sign'] as String? ?? '';
    if (sign != '+' && sign != '-' && sign != '') {
      throw FormatException(
        'Item attribute sign must be +, - or empty '
        '($sign)',
      );
    }
    return ItemAttribute(
      sign: sign,
      label: _requiredString(json, 'label'),
      values: _numList(json, 'values'),
      isPercentage: _requiredBool(json, 'is_percentage'),
    );
  }

  /// `+` or `-` when the feed's heading carried a sign (stat rows do); empty
  /// for the few headings that are bare labels ("EFFECT RADIUS:").
  final String sign;

  /// Decoded heading text ("All Attributes"): Valve's `$token` placeholders
  /// resolved at conversion time, unknown tokens left visible.
  final String label;

  /// One value per Item level (a single entry for everything but levelable
  /// Items such as Dagon).
  final List<double> values;

  /// When true, the UI appends `%` to the displayed values.
  final bool isPercentage;

  /// The row as the UI renders it: `+10 Strength`, `+3% Max Mana`, or
  /// `+6/7/8/9/10 All Attributes` for a levelable Item.
  String get display {
    final renderedValues = values
        .map((value) => _trimTrailingZeros(value))
        .join('/');
    final prefix = '$sign$renderedValues${isPercentage ? '%' : ''}';
    return label.isEmpty ? prefix : '$prefix $label';
  }
}

/// One section of the Item's effect text, split from the description's
/// `<h1>` headings by the converter.
class ItemEffect {
  const ItemEffect({
    required this.kind,
    required this.title,
    required this.text,
  });

  factory ItemEffect.fromJson(Map<String, dynamic> json) => ItemEffect(
    kind: ItemEffectKind.parse(_requiredString(json, 'kind')),
    title: json['title'] as String? ?? '',
    text: _requiredString(json, 'text'),
  );

  final ItemEffectKind kind;

  /// The heading's name ("Blink", "Damage Block"); empty when the feed
  /// served description text with no heading at all.
  final String title;

  /// Fully resolved plain text (`%token%` substituted at conversion).
  final String text;
}

/// What a description section IS, as the feed's `<h1>` prefix encodes it.
enum ItemEffectKind {
  active,
  passive,
  toggle,
  use,

  /// A heading the feed does not prefix with one of the four verbs (item
  /// sub-sections such as "Archer:"); rendered without a badge.
  other;

  String get wireName => name;

  /// Badge text shown next to the title.
  String get label => switch (this) {
    active => 'Active',
    passive => 'Passive',
    toggle => 'Toggle',
    use => 'Use',
    other => '',
  };

  static ItemEffectKind parse(String wireName) => values.firstWhere(
    (k) => k.wireName == wireName,
    orElse: () => throw FormatException('Unknown item effect kind "$wireName"'),
  );
}

/// 1.0 → "1", 4.5 → "4.5", 6.0 → "6" (the front-end's lean number style).
String _trimTrailingZeros(double value) {
  if (value == value.truncateToDouble()) return value.toInt().toString();
  return value.toString();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Item detail: "$key" missing or not an int');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Item detail: "$key" missing or not a bool');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Item detail: "$key" missing or empty');
  }
  return value;
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Item detail: "$key" missing or not an object');
  }
  return value;
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Item detail: "$key" missing or not a list');
  }
  return value
      .map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw FormatException('Item detail: "$key" entry is not an object');
        }
        return entry;
      })
      .toList(growable: false);
}

List<double> _numList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Item detail: "$key" missing or not a list');
  }
  return value
      .map((entry) {
        if (entry is! num) {
          throw FormatException('Item detail: "$key" entry is not a number');
        }
        return entry.toDouble();
      })
      .toList(growable: false);
}

List<int> _intList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Item detail: "$key" missing or not a list');
  }
  return value
      .map((entry) {
        if (entry is! int) {
          throw FormatException('Item detail: "$key" entry is not an int');
        }
        return entry;
      })
      .toList(growable: false);
}

List<String> _optionalStringList(Map<String, dynamic> json, String key) {
  final value = json[key] ?? const [];
  if (value is! List) {
    throw FormatException('Item detail: "$key" not a list');
  }
  return value.cast<String>();
}
