// Valve herolist feed → app-schema hero index.
//
// Shared by the snapshot tool (bundled asset, `tool/snapshot.dart`) and the
// refresh unit (override, `heroes_snapshot_unit.dart`): both MUST emit the
// same schema, or a refreshed override would be unreadable by the parser
// that reads the bundled asset. One converter, two writers — drift is
// impossible by construction.

import '../../core/cdn/cdn_urls.dart';

/// Version of the emitted app schema. Bump when the file shape changes and
/// the parsing test (`test/features/heroes/hero_index_test.dart`) with it.
const int heroIndexSchemaVersion = 1;

/// Maps one feed hero onto the app schema the app parses.
///
/// Feed (`result.data.heroes[]`), verified live 2026-10-20:
/// `{"id":1,"name":"npc_dota_hero_antimage","name_loc":"Anti-Mage",
///   "name_english_loc":"Anti-Mage","primary_attr":1,"complexity":1}`.
Map<String, Object?> heroToAppSchema(Map<String, dynamic> hero) {
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
    'primary_attribute': attribute,
    'complexity': _required<num>(hero, 'complexity').toInt(),
    'portrait_url': CdnUrls.heroPortrait(
      CdnUrls.heroKeyFromValveName(valveKey),
    ),
  };
}

/// `primary_attr` as the feeds encode it (herolist and herodata agree; both
/// verified live 2026-10-20). The app schema stores the string instead, so a
/// Valve-side renumbering breaks the conversion loudly rather than silently
/// mislabelling heroes — the parsing test pins every emitted name.
const Map<int, String> feedPrimaryAttributes = {
  0: 'strength',
  1: 'agility',
  2: 'intelligence',
  3: 'universal',
};

/// Converts a whole herolist feed document into the app-schema index the
/// app parses (same shape as the bundled asset).
Map<String, Object?> heroIndexFromFeed(
  Map<String, dynamic> feed, {
  required String locale,
}) => {
  'schema_version': heroIndexSchemaVersion,
  'locale': locale,
  'heroes': _feedHeroes(feed, locale).map(heroToAppSchema).toList(),
};

List<Map<String, dynamic>> _feedHeroes(
  Map<String, dynamic> feed,
  String locale,
) {
  final result = feed['result'];
  if (result is! Map<String, dynamic>) {
    throw const FormatException('Feed shape drift: "result" missing');
  }
  switch (result['data']?['heroes']) {
    case final List<dynamic> list:
      return list.cast<Map<String, dynamic>>();
    case _ when result.containsKey('status'):
      throw FormatException(
        'Feed rejected language=$locale (status ${result['status']}). '
        'Use a Valve language token such as english, schinese, koreana, russian.',
      );
    case _:
      throw const FormatException(
        'Feed shape drift: result.data.heroes missing',
      );
  }
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
