// Valve herodata feed → app-schema hero detail.
//
// Shared by the snapshot tool (bundled per-Hero asset, `tool/snapshot.dart`)
// and the refresh unit (`heroes_snapshot_unit.dart`): both MUST emit the
// same schema, or a refreshed override would be unreadable by the parser
// that reads the bundled asset. One converter, two writers — drift is
// impossible by construction.
//
// Display strings replicate Valve's own decode tables and token
// substitutions, extracted from dota2.com's front-end `main.js` (verified
// live 2026-10-21): behaviour/targeting/damage/dispel tags, `%token%`
// substitution from special values, and Talent `{s:token}` resolution from
// own values and ability bonuses. The app renders plain text only.

import '../../core/cdn/cdn_urls.dart';
import 'hero_detail.dart';
import 'hero_feed_to_index.dart' show feedPrimaryAttributes;

/// Converts one herodata feed document (one Hero) into the app-schema
/// detail file the app parses (same shape as the bundled per-Hero asset).
///
/// Feed (`result.data.heroes[0]`), verified live 2026-10-21:
/// `{"id":1,"name":"npc_dota_hero_antimage","name_loc":"Anti-Mage",
///   "bio_loc":…,"abilities":[…],"talents":[8],"facets":[],"facet_abilities":[]}`
Map<String, Object?> heroDetailFromFeed(
  Map<String, dynamic> feed, {
  required String locale,
}) {
  final hero = _feedHero(feed, locale);
  final abilities = _requiredList(hero, 'abilities');
  final grantedFacetAbilities = _facetGrantedAbilities(hero);
  return {
    'schema_version': heroDetailSchemaVersion,
    'locale': locale,
    'hero': _heroProfile(hero),
    'abilities': abilities
        .map((ability) => _abilityToAppSchema(ability))
        .toList(growable: false),
    'talents': _talents(hero, [
      ...abilities,
      ...grantedFacetAbilities,
    ]).toList(growable: false),
    'facets': _facets(hero, abilities).toList(growable: false),
  };
}

// --- hero profile -----------------------------------------------------------

Map<String, Object?> _heroProfile(Map<String, dynamic> hero) {
  final valveKey = _required<String>(hero, 'name');
  final feedAttr = _required<num>(hero, 'primary_attr').toInt();
  final attribute = feedPrimaryAttributes[feedAttr];
  if (attribute == null) {
    throw FormatException(
      'Unknown primary_attr $feedAttr for $valveKey — feed drifted, '
      'update feedPrimaryAttributes before re-running.',
      valveKey,
    );
  }
  return {
    'id': _required<num>(hero, 'id').toInt(),
    'valve_key': valveKey,
    'localized_name': _required<String>(hero, 'name_loc'),
    'one_liner': _required<String>(hero, 'npe_desc_loc'),
    'primary_attribute': attribute,
    'complexity': _required<num>(hero, 'complexity').toInt(),
    'portrait_url': CdnUrls.heroPortrait(
      CdnUrls.heroKeyFromValveName(valveKey),
    ),
    'attributes': {
      'strength': _attribute(hero, 'str'),
      'agility': _attribute(hero, 'agi'),
      'intelligence': _attribute(hero, 'int'),
    },
    'combat': {
      'damage_min': _required<num>(hero, 'damage_min').toInt(),
      'damage_max': _required<num>(hero, 'damage_max').toInt(),
      'attack_rate': _required<num>(hero, 'attack_rate').toDouble(),
      'attack_range': _required<num>(hero, 'attack_range').toInt(),
      'projectile_speed': _required<num>(hero, 'projectile_speed').toInt(),
      // The site truncates armor to two decimals; keep floats lean.
      'armor': _truncate2(_required<num>(hero, 'armor')),
      'magic_resistance': _required<num>(hero, 'magic_resistance'),
      'movement_speed': _required<num>(hero, 'movement_speed').toInt(),
      'turn_rate': _required<num>(hero, 'turn_rate').toDouble(),
      'sight_range_day': _required<num>(hero, 'sight_range_day').toInt(),
      'sight_range_night': _required<num>(hero, 'sight_range_night').toInt(),
    },
    'bio': _required<String>(hero, 'bio_loc').trim(),
  };
}

Map<String, Object?> _attribute(Map<String, dynamic> hero, String prefix) => {
  'base': _required<num>(hero, '${prefix}_base'),
  'gain': _required<num>(hero, '${prefix}_gain'),
};

// --- abilities --------------------------------------------------------------

Map<String, Object?> _abilityToAppSchema(Map<String, dynamic> ability) {
  final abilityName = _required<String>(ability, 'name');
  final specialValues = _requiredList(ability, 'special_values');

  var description = _required<String>(ability, 'desc_loc');
  var scepterText = _stringOrEmpty(ability, 'scepter_loc');
  var shardText = _stringOrEmpty(ability, 'shard_loc');
  final notes = _requiredList(
    ability,
    'notes_loc',
  ).cast<String>().toList(growable: false);

  // Token substitution, in the front-end's order: shard-specific values
  // first, then scepter-specific ones, then base values — so the upgrade
  // texts prefer their own values over the base ones.
  var substitutedNotes = notes;
  for (final raw in specialValues) {
    final value = _asObject(raw);
    final name = _required<String>(value, 'name');
    final shardValues = _numListOf(value['values_shard']);
    if (shardValues.isNotEmpty) {
      final replacement = _fmt(shardValues.first);
      for (final key in _variants(name, prefixes: ['', 'bonus_', 'shard_'])) {
        shardText = shardText.replaceAll('%$key%', replacement);
      }
    }
    final scepterValues = _numListOf(value['values_scepter']);
    if (scepterValues.isNotEmpty) {
      final replacement = _fmt(scepterValues.first);
      for (final key in _variants(name, prefixes: ['', 'bonus_', 'scepter_'])) {
        scepterText = scepterText.replaceAll('%$key%', replacement);
      }
    }
    final base = _numListOf(value['values_float']);
    final replacement = base.isEmpty ? '0' : _fmt(base.first);
    description = _replaceAllVariants(description, name, replacement);
    scepterText = _replaceAllVariants(scepterText, name, replacement);
    shardText = _replaceAllVariants(shardText, name, replacement);
    substitutedNotes = substitutedNotes
        .map((note) => _replaceAllVariants(note, name, replacement))
        .toList(growable: false);
  }
  description = _escapePercents(description);
  scepterText = _escapePercents(scepterText);
  shardText = _escapePercents(shardText);

  final grantedByScepter = ability['ability_is_granted_by_scepter'] == true;
  final grantedByShard = ability['ability_is_granted_by_shard'] == true;

  final grantedBy = grantedByScepter
      ? 'scepter'
      : grantedByShard
      ? 'shard'
      : null;

  final target = _targetTag(
    _required<num>(ability, 'target_team').toInt(),
    _required<num>(ability, 'target_type').toInt(),
  );
  final immunity = _required<num>(ability, 'immunity').toInt();
  final damage = _required<num>(ability, 'damage').toInt();
  final dispellable = _required<num>(ability, 'dispellable').toInt();
  final damages = _numListOf(ability['damages']);

  return {
    'name': abilityName,
    'display_name': _required<String>(ability, 'name_loc'),
    'icon_url': CdnUrls.abilityIcon(abilityName),
    'description': _plainText(description),
    if (_stringOrEmpty(ability, 'lore_loc').trim().isNotEmpty)
      'lore': _plainText(_stringOrEmpty(ability, 'lore_loc').trim()),
    'notes': substitutedNotes
        .map((note) => _plainText(_escapePercents(note)))
        .toList(growable: false),
    'is_innate': ability['ability_is_innate'] == true,
    'is_ultimate': _required<num>(ability, 'type').toInt() == 1,
    'granted_by': ?grantedBy,
    'behavior_tag': _behaviorTag(_behaviorBits(ability)),
    'target': ?target,
    if (immunityTags.containsKey(immunity))
      'pierces_spell_immunity': immunityTags[immunity]!,
    if (damageTags.containsKey(damage)) 'damage_type': damageTags[damage]!,
    if (dispellableTags.containsKey(dispellable))
      'dispellable': dispellableTags[dispellable]!,
    'cast_ranges': _numListOf(ability['cast_ranges']),
    'mana_costs': _numListOf(ability['mana_costs']),
    'cooldowns': _numListOf(ability['cooldowns']),
    if (damages.fold<double>(0, (sum, value) => sum + value) > 0)
      'damages': damages,
    'special_values': [
      for (final raw in specialValues)
        if (_stringOrEmpty(_asObject(raw), 'heading_loc').isNotEmpty)
          {
            'heading': _required<String>(_asObject(raw), 'heading_loc'),
            'values': _numListOf(_asObject(raw)['values_float']),
            'is_percentage': _asObject(raw)['is_percentage'] == true,
          },
    ],
    if (scepterText.trim().isNotEmpty) 'scepter_text': _plainText(scepterText),
    if (shardText.trim().isNotEmpty) 'shard_text': _plainText(shardText),
  };
}

int _behaviorBits(Map<String, dynamic> ability) =>
    int.parse(_required<String>(ability, 'behavior'));

/// The front-end shows ONE behaviour tag: a first-match chain over the
/// bitmask, with Passive as the final fallback branch (never an override).
String _behaviorTag(int behavior) {
  if (behavior & 65536 != 0) return 'Aura';
  if (behavior & 4 != 0) return 'No Target';
  if (behavior & 8 != 0) return 'Unit Target';
  if (behavior & 16 != 0) return 'Point Target';
  if (behavior & 32 != 0) return 'Point AOE';
  if (behavior & 128 != 0) return 'Channeled';
  if (behavior & 512 != 0) return 'Toggle';
  if (behavior & 4096 != 0) return 'Auto-Cast';
  if (behavior & 2 != 0) return 'Passive';
  return '';
}

/// Spell-immunity piercing, as the front-end decodes it (1/3 yes, 2/4 no,
/// 5 allies-only; 0 = not applicable, no tag).
const Map<int, String> immunityTags = {
  1: 'Yes',
  3: 'Yes',
  2: 'No',
  4: 'No',
  5: 'Allies Yes, Enemies No',
};

/// Damage types, as the front-end decodes them (0 = no damage, no tag).
const Map<int, String> damageTags = {
  1: 'Physical',
  2: 'Magical',
  4: 'Pure',
  8: 'HP Removal',
};

/// Dispellability, as the front-end decodes it (0 = not applicable, no tag).
const Map<int, String> dispellableTags = {
  1: 'Strong Dispel',
  2: 'Yes',
  3: 'No',
};

/// Targeting, as the front-end decodes it: team first, then the target-type
/// bitmask tried from broadest to narrowest. Null when team == 0.
String? _targetTag(int team, int type) {
  if (team == 1) {
    if (type & 7 == 7) return 'Allied Units and Buildings';
    if (type & 3 == 3) return 'Allied Units';
    if (type & 5 == 5) return 'Allied Heroes and Buildings';
    if (type & 1 == 1) return 'Allied Heroes';
    if (type & 2 == 2) return 'Allied Creeps';
    return 'Allies';
  }
  if (team == 2) {
    if (type & 7 == 7) return 'Enemy Units and Buildings';
    if (type & 3 == 3) return 'Enemy Units';
    if (type & 5 == 5) return 'Enemy Heroes and Buildings';
    if (type & 1 == 1) return 'Enemy Heroes';
    if (type & 2 == 2) return 'Enemy Creeps';
    return 'Enemies';
  }
  if (team == 3) return type & 1 == 1 ? 'Heroes' : 'Units';
  return null;
}

// --- talents ----------------------------------------------------------------

/// Resolves every Talent's `{s:token}` text exactly like the front-end:
/// the Talent's own special values first, then bonuses referencing the
/// Talent's name from every ability's (and facet ability's) special values.
Iterable<String> _talents(
  Map<String, dynamic> hero,
  List<dynamic> allAbilities,
) sync* {
  final talents = _requiredList(hero, 'talents');
  for (final raw in talents) {
    final talent = _asObject(raw);
    var text = _required<String>(talent, 'name_loc');
    for (final rawValue in _requiredList(talent, 'special_values')) {
      final value = _asObject(rawValue);
      final floats = _numListOf(value['values_float']);
      if (floats.isNotEmpty) {
        text = text.replaceAll(
          '{s:${_required<String>(value, 'name')}}',
          _fmt(floats.first),
        );
      }
    }
    for (final rawAbility in allAbilities) {
      final ability = _asObject(rawAbility);
      for (final rawValue in _requiredList(ability, 'special_values')) {
        final value = _asObject(rawValue);
        for (final rawBonus in _numEntryList(value['bonuses'])) {
          final bonus = _asObject(rawBonus);
          if (bonus['name'] == talent['name']) {
            final bonusValue = (bonus['value'] as num).abs();
            text = text.replaceAll(
              '{s:bonus_${_required<String>(value, 'name')}}',
              _fmt(bonusValue),
            );
          }
        }
      }
    }
    yield text.replaceAll('--', '-');
  }
}

// --- facets -----------------------------------------------------------------

/// The abilities a facet grants, per the feed's `facet_abilities[i]`
/// (parallel to `facets[i]`; an empty list when the feed predates facets).
List<dynamic> _facetGrantedAbilities(Map<String, dynamic> hero) {
  final result = <dynamic>[];
  final facets = _requiredList(hero, 'facets');
  final granted = _requiredList(hero, 'facet_abilities');
  for (var i = 0; i < facets.length && i < granted.length; i++) {
    result.addAll(_requiredList(_asObject(granted[i]), 'abilities'));
  }
  return result;
}

/// The Facets section's data, mirroring the official front-end's Facet card:
/// title, resolved description, granted abilities, and the base abilities
/// the Facet changes (its `facets_loc` text or a matching `facet_bonus`).
///
/// Empty on current data — Facets were removed from the game in patch 7.41,
/// but the pipeline stays complete for their return (issue decision).
Iterable<Map<String, Object?>> _facets(
  Map<String, dynamic> hero,
  List<dynamic> abilities,
) sync* {
  final facets = _requiredList(hero, 'facets');
  final grantedLists = _requiredList(hero, 'facet_abilities');
  for (var i = 0; i < facets.length; i++) {
    final facet = _asObject(facets[i]);
    final facetName = _required<String>(facet, 'name');
    final granted = i < grantedLists.length
        ? _requiredList(_asObject(grantedLists[i]), 'abilities')
        : const <dynamic>[];

    // Token values for this facet: facet_bonus values from every ability,
    // then the granted abilities' own values (front-end order).
    final values = <String, String>{};
    for (final rawAbility in [...abilities, ...granted]) {
      final ability = _asObject(rawAbility);
      for (final rawValue in _requiredList(ability, 'special_values')) {
        final value = _asObject(rawValue);
        final facetBonus = _asObject(value['facet_bonus']);
        if (facetBonus['name'] != facetName) continue;
        final bonusValues = _numListOf(facetBonus['values']);
        if (bonusValues.isEmpty) continue;
        values['bonus_${_required<String>(value, 'name')}'] = bonusValues
            .map((v) => _fmt(v))
            .join('/');
      }
    }
    for (final rawGranted in granted) {
      final grantedAbility = _asObject(rawGranted);
      values['facet_ability_name'] = _required<String>(
        grantedAbility,
        'name_loc',
      );
      for (final rawValue in _requiredList(grantedAbility, 'special_values')) {
        final value = _asObject(rawValue);
        final floats = _numListOf(value['values_float']);
        if (floats.isEmpty) continue;
        final joined = floats.map((v) => _fmt(v)).join('/');
        values[_required<String>(value, 'name')] = joined;
        values['bonus_${_required<String>(value, 'name')}'] = joined;
      }
    }

    String resolve(String text) {
      var resolved = text;
      values.forEach((key, value) {
        resolved = resolved.replaceAll('{s:$key}', value);
        resolved = resolved.replaceAll('%$key%', value);
      });
      return _plainText(_escapePercents(resolved));
    }

    final changed = <Map<String, Object>>[];
    for (final rawAbility in abilities) {
      final ability = _asObject(rawAbility);
      final facetsLoc = _numEntryList(ability['facets_loc']);
      final facetText = i < facetsLoc.length && facetsLoc[i] is String
          ? facetsLoc[i]! as String
          : '';
      final changesThis = _requiredList(ability, 'special_values').any(
        (rawValue) =>
            _asObject(_asObject(rawValue)['facet_bonus'])['name'] == facetName,
      );
      if (facetText.isEmpty && !changesThis) continue;
      changed.add({
        'display_name': _required<String>(ability, 'name_loc'),
        'description': resolve(
          facetText.isEmpty
              ? _required<String>(ability, 'desc_loc')
              : facetText,
        ),
      });
    }

    yield {
      'title': _required<String>(facet, 'title_loc'),
      'description': resolve(_required<String>(facet, 'description_loc')),
      'granted': [
        for (final rawGranted in granted)
          {
            'display_name': _required<String>(
              _asObject(rawGranted),
              'name_loc',
            ),
            'description': resolve(
              _required<String>(_asObject(rawGranted), 'desc_loc'),
            ),
          },
      ],
      'changed': changed,
    };
  }
}

// --- text helpers -----------------------------------------------------------

/// `name`, `name` lowercased, and the prefixed variants — the keys the
/// front-end replaces in upgrade texts.
Iterable<String> _variants(String name, {required List<String> prefixes}) {
  final lower = name.toLowerCase();
  return [
    for (final prefix in prefixes) ...['$prefix$name', '$prefix$lower'],
  ];
}

String _replaceAllVariants(String text, String name, String replacement) {
  var result = text;
  for (final key in _variants(name, prefixes: [''])) {
    result = result.replaceAll('%$key%', replacement);
  }
  return result;
}

/// `%%` → `%` (the feed escapes literal percent signs).
String _escapePercents(String text) => text.replaceAll('%%', '%');

/// Feed texts carry a little inline HTML; the app renders plain text.
String _plainText(String text) {
  var result = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h[12]>', caseSensitive: false), '\n')
      .replaceAll(r'<\/>', '</')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  // Collapse the trailing blank lines some bios end with.
  result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return result;
}

/// Formats a number like the front-end: truncated to two decimals, no
/// trailing ".0" (65 → "65", 1.8 → "1.8", 6.166667 → "6.16").
String _fmt(num value) {
  final truncated = _truncate2(value);
  if (truncated == truncated.truncateToDouble()) {
    return truncated.toInt().toString();
  }
  return truncated.toString();
}

double _truncate2(num value) => (value.toDouble() * 100).floorToDouble() / 100;

// --- feed access ------------------------------------------------------------

Map<String, dynamic> _feedHero(Map<String, dynamic> feed, String locale) {
  final result = feed['result'];
  if (result is! Map<String, dynamic>) {
    throw const FormatException('Feed shape drift: "result" missing');
  }
  switch (result['data']?['heroes']) {
    case final List<dynamic> list when list.isNotEmpty:
      final hero = list.first;
      if (hero is! Map<String, dynamic>) {
        throw const FormatException('Feed shape drift: hero is not an object');
      }
      return hero;
    case _ when result.containsKey('status'):
      throw FormatException(
        'Feed rejected language=$locale (status ${result['status']}) '
        'or served no hero.',
      );
    default:
      throw const FormatException(
        'Feed shape drift: result.data.heroes missing',
      );
  }
}

List<dynamic> _requiredList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) {
    throw FormatException(
      'Feed shape drift: "$key" missing or not a list',
      map.toString(),
    );
  }
  return value;
}

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

List<dynamic> _numEntryList(Object? value) =>
    value is List ? value : const <dynamic>[];

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
