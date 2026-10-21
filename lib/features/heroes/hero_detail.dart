/// Hero detail: the app schema for one per-Hero detail file.
///
/// The contract is the FILE, not this class: `dart run tool/snapshot.dart`
/// emits `assets/data/hero_<id>.<locale>.json` and
/// `test/features/heroes/hero_detail_test.dart` parses that real file to pin
/// the schema. Parsing is strict — anything unrecognised throws
/// [FormatException] so drift surfaces in CI instead of rendering garbage.
///
/// All texts are already resolved: `%token%` / `{s:token}` substitutions from
/// the feed's special values happened at conversion time (one converter,
/// `hero_feed_to_detail.dart`), so the app renders plain strings.
library;

import 'hero_index.dart';

/// Current schema version of the emitted per-Hero detail files.
const int heroDetailSchemaVersion = 1;

/// The override-store unit for one Hero's detail: same base name as the
/// bundled asset, so a refreshed file is the same document, one generation
/// newer. Lives here (pure Dart) so the snapshot tool can emit the same
/// names without importing the repository (Riverpod ≠ `dart run`-able).
///
/// The id and locale live in the file name so future UI languages are one
/// more snapshot file per Hero, not a code change; the app reads the
/// English ones (v1 is English-only, per spec).
String heroDetailUnitName(int heroId, {String locale = 'english'}) =>
    'hero_$heroId.$locale.json';

/// Bundled asset path for one Hero's detail file (the app bundles English).
String heroDetailAssetPath(int heroId, {String locale = 'english'}) =>
    'assets/data/${heroDetailUnitName(heroId, locale: locale)}';

/// One Hero's complete offline reference page, as bundled per Hero id.
class HeroDetail {
  const HeroDetail({
    required this.schemaVersion,
    required this.locale,
    required this.hero,
    required this.abilities,
    required this.talents,
    required this.facets,
  });

  factory HeroDetail.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != heroDetailSchemaVersion) {
      throw FormatException(
        'Unsupported hero-detail schema_version $schemaVersion '
        '(app expects $heroDetailSchemaVersion)',
      );
    }
    return HeroDetail(
      schemaVersion: schemaVersion,
      locale: _requiredString(json, 'locale'),
      hero: HeroProfile.fromJson(_requiredObject(json, 'hero')),
      abilities: _objectList(
        json,
        'abilities',
      ).map(AbilityDetail.fromJson).toList(growable: false),
      talents: _stringList(json, 'talents'),
      facets: _objectList(
        json,
        'facets',
      ).map(HeroFacet.fromJson).toList(growable: false),
    );
  }

  final int schemaVersion;

  /// Valve feed language token the texts were snapshotted in.
  final String locale;

  /// Identity, attributes, combat stats, and lore.
  final HeroProfile hero;

  /// The Hero's abilities in feed order (basic, innate, ultimate).
  final List<AbilityDetail> abilities;

  /// The eight resolved Talent texts in feed order: pair (2i, 2i+1) is the
  /// level 10+5i tier, option 2i on the tree's right, 2i+1 on its left
  /// (mirrors the official Talent tree, which renders top tier first).
  final List<String> talents;

  /// The Hero's Facets. Empty on current data (Facets were removed from the
  /// game in patch 7.41), so the screen hides the section when empty — but
  /// the pipeline stays complete for their return.
  final List<HeroFacet> facets;
}

/// Identity, one-liner, primary attribute, complexity, portrait, attributes,
/// combat stats, and the full biography for the detail page header.
class HeroProfile {
  const HeroProfile({
    required this.id,
    required this.valveKey,
    required this.localizedName,
    required this.oneLiner,
    required this.primaryAttribute,
    required this.complexity,
    required this.portraitUrl,
    required this.attributes,
    required this.combat,
    required this.bio,
  });

  factory HeroProfile.fromJson(Map<String, dynamic> json) {
    final complexity = _requiredInt(json, 'complexity');
    if (complexity < 1 || complexity > 3) {
      throw FormatException('Hero complexity $complexity out of 1–3 range');
    }
    return HeroProfile(
      id: _requiredInt(json, 'id'),
      valveKey: _requiredString(json, 'valve_key'),
      localizedName: _requiredString(json, 'localized_name'),
      oneLiner: _requiredString(json, 'one_liner'),
      primaryAttribute: PrimaryAttribute.parse(
        _requiredString(json, 'primary_attribute'),
      ),
      complexity: complexity,
      portraitUrl: _requiredString(json, 'portrait_url'),
      attributes: HeroAttributes.fromJson(_requiredObject(json, 'attributes')),
      combat: HeroCombatStats.fromJson(_requiredObject(json, 'combat')),
      bio: _requiredString(json, 'bio'),
    );
  }

  final int id;
  final String valveKey;
  final String localizedName;

  /// The npe_desc_loc one-liner ("Slashes his foes with mana-draining
  /// attacks"), shown under the name.
  final String oneLiner;

  final PrimaryAttribute primaryAttribute;
  final int complexity;
  final String portraitUrl;
  final HeroAttributes attributes;
  final HeroCombatStats combat;

  /// The full biography (bio_loc).
  final String bio;
}

/// The three attributes' base values and per-level gains, keyed by wire
/// name (`strength`, `agility`, `intelligence` — Universal heroes display
/// these same three attributes).
class HeroAttributes {
  const HeroAttributes({
    required this.strength,
    required this.agility,
    required this.intelligence,
  });

  factory HeroAttributes.fromJson(Map<String, dynamic> json) => HeroAttributes(
    strength: _attribute(json, 'strength'),
    agility: _attribute(json, 'agility'),
    intelligence: _attribute(json, 'intelligence'),
  );

  static AttributeValue _attribute(Map<String, dynamic> json, String key) {
    final entry = _requiredObject(json, key);
    return AttributeValue(
      base: _requiredNum(entry, 'base').toDouble(),
      gain: _requiredNum(entry, 'gain').toDouble(),
    );
  }

  final AttributeValue strength;
  final AttributeValue agility;
  final AttributeValue intelligence;
}

/// One attribute's base value and per-level gain.
class AttributeValue {
  const AttributeValue({required this.base, required this.gain});

  final double base;
  final double gain;
}

/// The detail page's Combat stats card, mirroring the official site's
/// attack/defense/mobility groups.
class HeroCombatStats {
  const HeroCombatStats({
    required this.damageMin,
    required this.damageMax,
    required this.attackRate,
    required this.attackRange,
    required this.projectileSpeed,
    required this.armor,
    required this.magicResistance,
    required this.movementSpeed,
    required this.turnRate,
    required this.sightRangeDay,
    required this.sightRangeNight,
  });

  factory HeroCombatStats.fromJson(Map<String, dynamic> json) =>
      HeroCombatStats(
        damageMin: _requiredNum(json, 'damage_min').toInt(),
        damageMax: _requiredNum(json, 'damage_max').toInt(),
        attackRate: _requiredNum(json, 'attack_rate').toDouble(),
        attackRange: _requiredNum(json, 'attack_range').toInt(),
        projectileSpeed: _requiredNum(json, 'projectile_speed').toInt(),
        armor: _requiredNum(json, 'armor').toDouble(),
        magicResistance: _requiredNum(json, 'magic_resistance').toDouble(),
        movementSpeed: _requiredNum(json, 'movement_speed').toInt(),
        turnRate: _requiredNum(json, 'turn_rate').toDouble(),
        sightRangeDay: _requiredNum(json, 'sight_range_day').toInt(),
        sightRangeNight: _requiredNum(json, 'sight_range_night').toInt(),
      );

  final int damageMin;
  final int damageMax;
  final double attackRate;
  final int attackRange;
  final int projectileSpeed;
  final double armor;
  final double magicResistance;
  final int movementSpeed;
  final double turnRate;
  final int sightRangeDay;
  final int sightRangeNight;
}

/// One Ability as its expandable card needs it: display texts, decoded
/// behaviour tags, cost rows, and the per-level special-value table.
class AbilityDetail {
  const AbilityDetail({
    required this.name,
    required this.displayName,
    required this.iconUrl,
    required this.description,
    required this.lore,
    required this.notes,
    required this.isInnate,
    required this.isUltimate,
    required this.grantedBy,
    required this.behaviorTag,
    required this.target,
    required this.piercesSpellImmunity,
    required this.damageType,
    required this.dispellable,
    required this.castRanges,
    required this.manaCosts,
    required this.cooldowns,
    required this.specialValues,
    required this.scepterText,
    required this.shardText,
  });

  factory AbilityDetail.fromJson(Map<String, dynamic> json) {
    final grantedBy = json['granted_by'];
    if (grantedBy != null && grantedBy != 'scepter' && grantedBy != 'shard') {
      throw FormatException('Unknown ability granted_by "$grantedBy"');
    }
    return AbilityDetail(
      name: _requiredString(json, 'name'),
      displayName: _requiredString(json, 'display_name'),
      iconUrl: _requiredString(json, 'icon_url'),
      description: _requiredString(json, 'description'),
      lore: json['lore'] as String? ?? '',
      notes: _optionalStringList(json, 'notes'),
      isInnate: _requiredBool(json, 'is_innate'),
      isUltimate: _requiredBool(json, 'is_ultimate'),
      grantedBy: grantedBy as String?,
      behaviorTag: json['behavior_tag'] as String? ?? '',
      target: json['target'] as String?,
      piercesSpellImmunity: json['pierces_spell_immunity'] as String?,
      damageType: json['damage_type'] as String?,
      dispellable: json['dispellable'] as String?,
      castRanges: _numList(json, 'cast_ranges'),
      manaCosts: _numList(json, 'mana_costs'),
      cooldowns: _numList(json, 'cooldowns'),
      specialValues: _objectList(
        json,
        'special_values',
      ).map(AbilitySpecialValue.fromJson).toList(growable: false),
      scepterText: json['scepter_text'] as String?,
      shardText: json['shard_text'] as String?,
    );
  }

  /// Valve's internal ability name (e.g. `antimage_blink`); also the CDN
  /// icon file name.
  final String name;
  final String displayName;
  final String iconUrl;

  /// Fully resolved description (`%token%` substituted at conversion).
  final String description;
  final String lore;
  final List<String> notes;

  final bool isInnate;
  final bool isUltimate;

  /// `'scepter'` / `'shard'` when the ability only exists with that
  /// Aghanim's upgrade, else null.
  final String? grantedBy;

  /// One decoded behaviour tag ("Passive", "Unit Target", …) — the official
  /// front-end shows a single tag; empty when the bitmask matches nothing.
  final String? behaviorTag;

  /// Decoded targeting ("Enemy Units", …), spell-immunity piercing, damage
  /// type, and dispellability — all null when the feed encodes "none".
  final String? target;
  final String? piercesSpellImmunity;
  final String? damageType;
  final String? dispellable;

  /// Per-level rows: cast range, mana cost, cooldown (one entry per ability
  /// level; a single 0 entry when the ability has none).
  final List<double> castRanges;
  final List<double> manaCosts;
  final List<double> cooldowns;

  /// The per-level value table: only the feed's heading'd special values
  /// (the ones the official tooltip renders as rows).
  final List<AbilitySpecialValue> specialValues;

  /// Aghanim's Scepter / Shard enhancement texts (resolved; null when the
  /// ability has no such enhancement).
  final String? scepterText;
  final String? shardText;
}

/// One row of an Ability's per-level value table.
class AbilitySpecialValue {
  const AbilitySpecialValue({
    required this.heading,
    required this.values,
    required this.isPercentage,
  });

  factory AbilitySpecialValue.fromJson(Map<String, dynamic> json) =>
      AbilitySpecialValue(
        heading: _requiredString(json, 'heading'),
        values: _numList(json, 'values'),
        isPercentage: _requiredBool(json, 'is_percentage'),
      );

  /// The feed's localized heading ("MANA BURNED PER HIT:").
  final String heading;

  /// One value per ability level.
  final List<double> values;

  /// When true, the UI appends `%` to the displayed values.
  final bool isPercentage;
}

/// One Facet: title, resolved description, the abilities it grants, and the
/// base abilities it changes (per the official front-end's Facet card).
class HeroFacet {
  const HeroFacet({
    required this.title,
    required this.description,
    required this.granted,
    required this.changed,
  });

  factory HeroFacet.fromJson(Map<String, dynamic> json) => HeroFacet(
    title: _requiredString(json, 'title'),
    description: _requiredString(json, 'description'),
    granted: _objectList(
      json,
      'granted',
    ).map(FacetAbility.fromJson).toList(growable: false),
    changed: _objectList(
      json,
      'changed',
    ).map(FacetAbility.fromJson).toList(growable: false),
  );

  final String title;
  final String description;

  /// Abilities this Facet newly grants.
  final List<FacetAbility> granted;

  /// Base abilities whose behaviour this Facet changes.
  final List<FacetAbility> changed;
}

/// A Facet's view of one Ability: its display name and the description it
/// has under that Facet.
class FacetAbility {
  const FacetAbility({required this.displayName, required this.description});

  factory FacetAbility.fromJson(Map<String, dynamic> json) => FacetAbility(
    displayName: _requiredString(json, 'display_name'),
    description: _requiredString(json, 'description'),
  );

  final String displayName;
  final String description;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Hero detail: "$key" missing or not an int');
  }
  return value;
}

num _requiredNum(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('Hero detail: "$key" missing or not a number');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Hero detail: "$key" missing or not a bool');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Hero detail: "$key" missing or empty');
  }
  return value;
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('Hero detail: "$key" missing or not an object');
  }
  return value;
}

List<Map<String, dynamic>> _objectList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Hero detail: "$key" missing or not a list');
  }
  return value
      .map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw FormatException('Hero detail: "$key" entry is not an object');
        }
        return entry;
      })
      .toList(growable: false);
}

List<double> _numList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Hero detail: "$key" missing or not a list');
  }
  return value
      .map((entry) {
        if (entry is! num) {
          throw FormatException('Hero detail: "$key" entry is not a number');
        }
        return entry.toDouble();
      })
      .toList(growable: false);
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Hero detail: "$key" missing or not a list');
  }
  return value
      .map((entry) {
        if (entry is! String || entry.isEmpty) {
          throw FormatException('Hero detail: "$key" entry missing or empty');
        }
        return entry;
      })
      .toList(growable: false);
}

List<String> _optionalStringList(Map<String, dynamic> json, String key) {
  final value = json[key] ?? const [];
  if (value is! List) {
    throw FormatException('Hero detail: "$key" not a list');
  }
  return value.cast<String>();
}
