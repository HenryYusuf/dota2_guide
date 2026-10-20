/// Hero index: the app schema for the bundled roster snapshot.
///
/// The contract is the FILE, not this class: `dart run tool/snapshot.dart`
/// emits `assets/data/heroes.<locale>.json` and
/// `test/features/heroes/hero_index_test.dart` parses that real file to pin
/// the schema. Parsing is strict — anything unrecognised throws
/// [FormatException] so drift surfaces in CI instead of rendering garbage.
library;

/// Current schema version of the emitted hero-index file.
const int heroIndexSchemaVersion = 1;

/// Primary attribute of a Hero — the first filter row on the Heroes tab
/// (Strength / Agility / Intelligence / Universal).
///
/// The feeds encode this as an int; the snapshot tool maps it to the stable
/// wire names, which are the enum's Dart names.
enum PrimaryAttribute {
  strength,
  agility,
  intelligence,
  universal;

  static PrimaryAttribute parse(String wireName) => values.firstWhere(
    (a) => a.name == wireName,
    orElse: () =>
        throw FormatException('Unknown primary attribute "$wireName"'),
  );
}

/// Parsed content of one bundled hero-index file.
class HeroIndex {
  const HeroIndex({
    required this.schemaVersion,
    required this.locale,
    required this.heroes,
  });

  factory HeroIndex.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != heroIndexSchemaVersion) {
      throw FormatException(
        'Unsupported hero-index schema_version $schemaVersion '
        '(app expects $heroIndexSchemaVersion)',
      );
    }
    final rawHeroes = json['heroes'];
    if (rawHeroes is! List) {
      throw const FormatException('Hero index: "heroes" missing or not a list');
    }
    return HeroIndex(
      schemaVersion: schemaVersion,
      locale: _requiredString(json, 'locale'),
      heroes: rawHeroes
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw FormatException('Hero entry is not an object: $raw');
            }
            return HeroSummary.fromJson(raw);
          })
          .toList(growable: false),
    );
  }

  /// Schema version the file declared (validated against
  /// [heroIndexSchemaVersion] during parsing).
  final int schemaVersion;

  /// Valve feed language token the names were snapshotted in
  /// (`english`, `russian`, …).
  final String locale;

  /// Roster in feed order. Sorting for display is the screen's business.
  final List<HeroSummary> heroes;
}

/// One Hero as the Heroes grid needs it: identity, filter fields, and the
/// Valve CDN portrait URL (streamed at runtime, never bundled — ADR-0001).
class HeroSummary {
  const HeroSummary({
    required this.id,
    required this.valveKey,
    required this.localizedName,
    required this.primaryAttribute,
    required this.complexity,
    required this.portraitUrl,
  });

  factory HeroSummary.fromJson(Map<String, dynamic> json) {
    final complexity = _requiredInt(json, 'complexity');
    if (complexity < 1 || complexity > 3) {
      throw FormatException('Hero complexity $complexity out of 1–3 range');
    }
    return HeroSummary(
      id: _requiredInt(json, 'id'),
      valveKey: _requiredString(json, 'valve_key'),
      localizedName: _requiredString(json, 'localized_name'),
      primaryAttribute: PrimaryAttribute.parse(
        _requiredString(json, 'primary_attribute'),
      ),
      complexity: complexity,
      portraitUrl: _requiredString(json, 'portrait_url'),
    );
  }

  /// Valve's numeric hero id (stable across locales).
  final int id;

  /// Valve key name, e.g. `npc_dota_hero_antimage`; also derives the portrait
  /// file name on the CDN.
  final String valveKey;

  /// Display name in the snapshot's locale; what name search matches against.
  final String localizedName;

  final PrimaryAttribute primaryAttribute;

  /// 1 (easy) – 3 (hard), as shown in-game.
  final int complexity;

  /// Absolute Valve CDN URL for the 256×144 portrait; loaded at runtime.
  final String portraitUrl;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Hero index: "$key" missing or not an int');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Hero index: "$key" missing or empty');
  }
  return value;
}
