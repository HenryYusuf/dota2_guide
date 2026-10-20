// Snapshot tool: fetches Valve's official key-free datafeeds once and emits
// app-schema JSON into the assets the app bundles, so the app is fully usable
// offline on first launch (ADR-0001: datafeeds only, never KV extraction).
//
// Usage:
//   dart run tool/snapshot.dart [--locale english] [--out assets/data]
//
// The locale flag accepts any Valve feed language token (`english`,
// `russian`, `schinese`, …) so future UI languages can be snapshotted without
// code changes; v1 bundles English only.

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/core/cdn/cdn_urls.dart';

/// Key-free hero-list feed. `language=` takes the Valve locale token.
const _heroListFeed = 'https://www.dota2.com/datafeed/herolist';

/// Version of the emitted app schema. Bump when the file shape changes and
/// the parsing test (`test/features/heroes/hero_index_test.dart`) with it.
const int heroIndexSchemaVersion = 1;

Future<void> main(List<String> arguments) async {
  final locale = _flagValue(arguments, '--locale') ?? 'english';
  final outDir = _flagValue(arguments, '--out') ?? 'assets/data';

  stdout.writeln('Fetching herolist feed (language=$locale)…');
  final feed = await _fetchJson('$_heroListFeed?language=$locale');
  final heroes = _feedHeroes(feed, locale);

  final index = <String, Object?>{
    'schema_version': heroIndexSchemaVersion,
    'locale': locale,
    'heroes': heroes.map(_toAppSchema).toList(),
  };

  final outFile = File('$outDir/heroes.$locale.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(index)}\n',
  );

  stdout.writeln('Emitted ${heroes.length} heroes → ${outFile.path}');
}

/// `primary_attr` as the feeds encode it (herolist and herodata agree; both
/// verified live 2026-10-20). The app schema stores the string instead, so a
/// Valve-side renumbering breaks the snapshot loudly rather than silently
/// mislabelling bundled heroes — the parsing test pins every emitted name.
const Map<int, String> _feedPrimaryAttributes = {
  0: 'strength',
  1: 'agility',
  2: 'intelligence',
  3: 'universal',
};

/// Maps one feed hero onto the app schema the app parses.
///
/// Feed (`result.data.heroes[]`), verified live 2026-10-20:
/// `{"id":1,"name":"npc_dota_hero_antimage","name_loc":"Anti-Mage",
///   "name_english_loc":"Anti-Mage","primary_attr":1,"complexity":1}`.
Map<String, Object?> _toAppSchema(Map<String, dynamic> hero) {
  final valveKey = _required<String>(hero, 'name');
  final feedAttr = _required<num>(hero, 'primary_attr').toInt();
  final attribute = _feedPrimaryAttributes[feedAttr];
  if (attribute == null) {
    throw FormatException(
      'Unknown primary_attr $feedAttr for $valveKey — feed drifted, '
      'update _feedPrimaryAttributes before re-running.',
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

Future<Map<String, dynamic>> _fetchJson(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'AegisCodex-snapshot/1.0');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode} from $url');
    }
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
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

String? _flagValue(List<String> arguments, String flag) {
  final index = arguments.indexOf(flag);
  if (index == -1) return null;
  if (index + 1 >= arguments.length) {
    throw FormatException('$flag requires a value');
  }
  return arguments[index + 1];
}
