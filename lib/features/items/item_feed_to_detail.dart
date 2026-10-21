// Valve itemdata feed → app-schema item detail.
//
// Shared by the snapshot tool (bundled per-Item asset, `tool/snapshot.dart`)
// and the refresh unit (`items_snapshot_unit.dart`): both MUST emit the same
// schema, or a refreshed override would be unreadable by the parser that
// reads the bundled asset. One converter, two writers — drift is impossible
// by construction.
//
// Empirical notes (verified live 2026-10-21, over all 544 items):
// - `itemdata?language=english&item_id=N` serves ONE item under
//   `result.data.items[0]`, in the same ability-shaped envelope herodata
//   uses (`desc_loc`, `special_values`, `cooldowns`, …) plus `item_cost` and
//   `item_neutral_tier`. `itemdetail` (the name you would guess) returns an
//   empty body — `itemdata` is the detail feed.
// - The description is a sequence of `<h1>Verb: Name</h1> body` sections
//   (47 items have more than one; 15 have plain text with no heading at
//   all), so Active/Passive/Toggle/Use text is split here, not at render.
// - Stat rows are the heading'd special values; their headings carry
//   `$token` placeholders (`+$all`, `+$str`, …) that the front-end resolves
//   from its own language table. This file carries the same decode table;
//   an UNKNOWN token is left visible rather than blanked (the heroes
//   converter's fail-soft posture).

import '../../core/cdn/cdn_urls.dart';
import 'item_detail.dart';
import 'shop_categories.dart';

/// One build's recipe step, resolved from the itemlist's `item_recipe_*`
/// entry plus that entry's price in the per-Item detail feed.
class ItemRecipeInfo {
  const ItemRecipeInfo({
    required this.combinationCost,
    required this.components,
  });

  /// What the recipe step costs (0 = free).
  final int combinationCost;

  /// Component Item ids, in the feed's order (the first recipe set — three
  /// Items serve several alternative sets: ward dispenser, power treads,
  /// trident).
  final List<int> components;
}

/// Resolves every Item's recipe step from the itemlist entries and the
/// per-Item costs fetched from `itemdata` (keyed by Valve item key).
///
/// A recipe step is the `item_recipe_<suffix>` entry paired with the Item of
/// key `item_<suffix>` — every one of the 129 recipe entries in the live
/// feed pairs this way, and each recipe entry carries its components.
Map<String, ItemRecipeInfo> itemRecipesFromItemlist(
  List<dynamic> entries,
  Map<String, int> costsByKey,
) {
  final recipes = <String, ItemRecipeInfo>{};
  for (final raw in entries) {
    final entry = _asObject(raw);
    final valveKey = _required<String>(entry, 'name');
    if (!isRecipeItemKey(valveKey)) continue;
    final baseKey = 'item_${valveKey.substring(itemRecipeKeyPrefix.length)}';
    final recipeSets = _entryList(entry['recipes']);
    if (recipeSets.isEmpty) continue;
    final components = _intListOf(_asObject(recipeSets.first)['items']);
    final cost = costsByKey[valveKey];
    if (cost == null) continue;
    recipes[baseKey] = ItemRecipeInfo(
      combinationCost: cost,
      components: components,
    );
  }
  return recipes;
}

/// The (Valve key, total cost) pair one itemdata feed document carries —
/// what the recipe-cost pass keys on (`item_recipe_*` entries are fetched
/// like everything else; their cost is a build's combination cost).
(String valveKey, int cost) itemCostFromFeed(
  Map<String, dynamic> feed, {
  String locale = 'english',
}) {
  final item = _feedItem(feed, locale);
  return (
    _required<String>(item, 'name'),
    _required<num>(item, 'item_cost').toInt(),
  );
}

/// Converts one itemdata feed document (one Item) into the app-schema detail
/// file the app parses (same shape as the bundled per-Item asset).
///
/// Feed (`result.data.items[0]`), verified live 2026-10-21:
/// `{"id":1,"name":"item_blink","name_loc":"Blink Dagger","desc_loc":…,
///   "lore_loc":…,"notes_loc":[…],"special_values":[…],"item_cost":2250,
///   "item_neutral_tier":4294967295,…}`
Map<String, Object?> itemDetailFromFeed(
  Map<String, dynamic> feed, {
  required String locale,
  ItemRecipeInfo? recipe,
}) {
  final item = _feedItem(feed, locale);
  final valveKey = _required<String>(item, 'name');
  final specialValues = _entryList(item['special_values']);

  // Token values feed every text: name → first value, like the front-end.
  final tokens = _tokenValues(specialValues);

  final description = _required<String>(item, 'desc_loc');
  final notes = _entryList(item['notes_loc'])
      .whereType<String>()
      .toList(growable: false);

  final feedTier = _required<num>(item, 'item_neutral_tier').toInt();
  final neutralTier = feedTier == 4294967295 ? null : feedTier;

  return {
    'schema_version': itemDetailSchemaVersion,
    'locale': locale,
    'item': {
      'id': _required<num>(item, 'id').toInt(),
      'valve_key': valveKey,
      'name': _stringOrEmpty(item, 'name_loc'),
      'icon_url': CdnUrls.itemIcon(valveKey),
      'shop_category': shopCategoryFor(
        valveKey: valveKey,
        neutralTier: neutralTier ?? nonNeutralTier,
      ).wireName,
      'neutral_tier': neutralTier,
      'total_cost': _required<num>(item, 'item_cost').toInt(),
      // A free recipe step is no step at all: 40 of the 129 recipe entries
      // price at 0, and a "combination cost: 0 gold" row would be noise.
      'combination_cost': switch (recipe?.combinationCost) {
        null => null,
        final int cost when cost > 0 => cost,
        _ => null,
      },
      'components': recipe?.components ?? const <int>[],
      'attributes': _attributes(specialValues),
      'effects': _effects(description, tokens),
      'notes': notes
          .map((note) => _resolvedText(note, tokens))
          .toList(growable: false),
      if (_stringOrEmpty(item, 'lore_loc').trim().isNotEmpty)
        'lore': _resolvedText(_stringOrEmpty(item, 'lore_loc').trim(), tokens),
    },
  };
}

// --- attributes -------------------------------------------------------------

/// The stat rows: every heading'd special value, decoded to
/// `{"sign","+"/"-"/"", "label", "values", "is_percentage"}`.
List<Map<String, Object?>> _attributes(List<dynamic> specialValues) {
  final rows = <Map<String, Object?>>[];
  for (final raw in specialValues) {
    final value = _asObject(raw);
    final heading = _stringOrEmpty(value, 'heading_loc');
    if (heading.isEmpty) continue;
    final sign = switch (heading.substring(0, 1)) {
      '-' => '-',
      '+' => '+',
      _ => '',
    };
    final label = _decodeHeadingTokens(
      _stripTags(sign.isEmpty ? heading : heading.substring(1)).trim(),
    );
    if (label.isEmpty) continue;
    rows.add({
      'sign': sign,
      'label': label,
      'values': _numListOf(value['values_float']),
      'is_percentage': value['is_percentage'] == true,
    });
  }
  return rows;
}

/// The front-end's attribute-heading tokens, as the game's own language
/// table names them (verified against every heading in the live feed,
/// 2026-10-21). Anything absent survives visibly in the emitted label.
const Map<String, String> itemHeadingTokens = {
  r'$agi': 'Agility',
  r'$all': 'All Attributes',
  r'$aoe_bonus': 'AOE Bonus',
  r'$armor': 'Armor',
  r'$attack': 'Attack Speed',
  r'$attack_pct': 'Attack Speed',
  r'$attack_range': 'Attack Range',
  r'$attack_range_all': 'Attack Range',
  r'$attack_range_melee': 'Melee Attack Range',
  r'$cast_range': 'Cast Range',
  r'$cooldown_reduction': 'Cooldown Reduction',
  r'$damage': 'Damage',
  r'$debuff_amp': 'Debuff Amplification',
  r'$evasion': 'Evasion',
  r'$healing_amp': 'Healing Amplification',
  r'$health': 'Health',
  r'$hp_regen': 'Health Regeneration',
  r'$int': 'Intelligence',
  r'$lifesteal': 'Lifesteal',
  r'$mana': 'Mana',
  r'$mana_regen': 'Mana Regeneration',
  r'$manacost_reduction': 'Mana Cost Reduction',
  r'$max_mana_percentage': 'Max Mana',
  r'$move_speed': 'Movement Speed',
  r'$primary_attribute': 'Primary Attribute',
  r'$projectile_speed': 'Projectile Speed',
  r'$restoration_amp': 'Restoration Amplification',
  r'$selected_attrib': 'Selected Attribute',
  r'$slow_resistance': 'Slow Resistance',
  r'$spell_lifesteal': 'Spell Lifesteal',
  r'$spell_resist': 'Magic Resistance',
  r'$status_resist': 'Status Resistance',
  r'$str': 'Strength',
};

/// Replaces every known `$token` in a heading, leaving unknown ones visible.
String _decodeHeadingTokens(String heading) {
  var result = heading;
  itemHeadingTokens.forEach((token, label) {
    result = result.replaceAll(token, label);
  });
  return result;
}

// --- effects ----------------------------------------------------------------

/// Splits the description's `<h1>Verb: Name</h1> body` sections into the
/// effect rows the detail page renders.
List<Map<String, Object?>> _effects(
  String description,
  Map<String, String> tokens,
) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return const [];

  final headingPattern = RegExp(r'<h1>(.*?)</h1>', dotAll: true);
  final headings = headingPattern.allMatches(trimmed).toList(growable: false);
  if (headings.isEmpty) {
    // 15 items carry a bare description with no heading ("Movement speed
    // bonuses from multiple pairs of boots do not stack.").
    final text = _resolvedText(trimmed, tokens);
    if (text.isEmpty) return const [];
    return [
      {'kind': ItemEffectKind.other.wireName, 'title': '', 'text': text},
    ];
  }

  final effects = <Map<String, Object?>>[];
  final lead = trimmed.substring(0, headings.first.start).trim();
  if (lead.isNotEmpty) {
    effects.add({
      'kind': ItemEffectKind.other.wireName,
      'title': '',
      'text': _resolvedText(lead, tokens),
    });
  }
  for (var i = 0; i < headings.length; i++) {
    final match = headings[i];
    final body = trimmed.substring(
      match.end,
      i + 1 < headings.length ? headings[i + 1].start : trimmed.length,
    );
    final text = _resolvedText(body, tokens);
    if (text.isEmpty) continue;
    final (kind, title) = _sectionKindAndTitle(
      _stripTags(match.group(1) ?? '').trim(),
    );
    effects.add({'kind': kind, 'title': title, 'text': text});
  }
  return effects;
}

/// `"Active: Blink"` → `('active', 'Blink')`. A heading without one of the
/// four verbs is an item sub-section (`"Archer:"`, `"Upgrade: …"`) and stays
/// kind `other` with the heading itself as the title.
(String, String) _sectionKindAndTitle(String heading) {
  final colon = heading.indexOf(':');
  if (colon == -1) {
    return (ItemEffectKind.other.wireName, _stripTrailingColon(heading));
  }
  final prefix = heading.substring(0, colon).trim().toLowerCase();
  final title = heading.substring(colon + 1).trim();
  final kind = switch (prefix) {
    'active' => ItemEffectKind.active,
    'passive' => ItemEffectKind.passive,
    'toggle' => ItemEffectKind.toggle,
    'use' => ItemEffectKind.use,
    _ => ItemEffectKind.other,
  };
  if (kind == ItemEffectKind.other) {
    return (kind.wireName, _stripTrailingColon(heading));
  }
  return (kind.wireName, title);
}

String _stripTrailingColon(String heading) => heading.trim().endsWith(':')
    ? heading.trim().substring(0, heading.trim().length - 1).trim()
    : heading.trim();

// --- text helpers -----------------------------------------------------------

/// `%token%` → the special value's first number, then the feed's inline
/// markup stripped to plain text (the app renders plain strings only).
String _resolvedText(String text, Map<String, String> tokens) {
  var result = text;
  tokens.forEach((name, value) {
    result = result.replaceAll('%$name%', value);
  });
  return _plainText(_escapePercents(result));
}

/// name → first value, formatted like the front-end (the feed's values are
/// always numeric; an absent token resolves to "0" rather than blanking).
Map<String, String> _tokenValues(List<dynamic> specialValues) {
  final tokens = <String, String>{};
  for (final raw in specialValues) {
    final value = _asObject(raw);
    final name = _required<String>(value, 'name');
    final values = _numListOf(value['values_float']);
    final replacement = values.isEmpty ? '0' : _formatNumber(values.first);
    tokens[name] = replacement;
    tokens[name.toLowerCase()] = replacement;
  }
  return tokens;
}

/// `%%` → `%` (the feed escapes literal percent signs).
String _escapePercents(String text) => text.replaceAll('%%', '%');

/// Feed texts carry a little inline HTML; the app renders plain text.
String _stripTags(String text) => text
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(r'<\/>', '</')
    .replaceAll(RegExp(r'<[^>]+>'), '');

String _plainText(String text) =>
    _stripTags(text).replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

/// Formats a number like the front-end: truncated to two decimals, no
/// trailing ".0" (65 → "65", 4.5 → "4.5", 6.166667 → "6.16").
String _formatNumber(num value) {
  final truncated = _truncate2(value);
  if (truncated == truncated.truncateToDouble()) {
    return truncated.toInt().toString();
  }
  return truncated.toString();
}

double _truncate2(num value) => (value.toDouble() * 100).floorToDouble() / 100;

// --- feed access ------------------------------------------------------------

Map<String, dynamic> _feedItem(Map<String, dynamic> feed, String locale) {
  final result = feed['result'];
  if (result is! Map<String, dynamic>) {
    throw const FormatException('Feed shape drift: "result" missing');
  }
  switch (result['data']?['items']) {
    case final List<dynamic> list when list.isNotEmpty:
      final item = list.first;
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Feed shape drift: item is not an object');
      }
      return item;
    case _ when result.containsKey('status'):
      throw FormatException(
        'Feed rejected language=$locale (status ${result['status']}) '
        'or served no item.',
      );
    default:
      throw const FormatException(
        'Feed shape drift: result.data.items missing',
      );
  }
}

List<dynamic> _entryList(Object? value) =>
    value is List ? value : const <dynamic>[];

Map<String, dynamic> _asObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('Feed shape drift: expected an object, got $value');
  }
  return value;
}

List<num> _numListOf(Object? value) {
  if (value is! List) return const [];
  return value.map((entry) => entry as num).toList(growable: false);
}

List<int> _intListOf(Object? value) =>
    _numListOf(value).map((entry) => entry.toInt()).toList(growable: false);

String _stringOrEmpty(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value : '';
}

T _required<T>(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! T) {
    throw FormatException(
      'Feed shape drift: "$key" missing or not $T',
      map.toString(),
    );
  }
  return value;
}
