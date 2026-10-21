// Snapshot tool: fetches Valve's official key-free datafeeds once and emits
// app-schema JSON into the assets the app bundles, so the app is fully usable
// offline on first launch (ADR-0001: datafeeds only, never KV extraction).
//
// Usage:
//   dart run tool/snapshot.dart [--locale english] [--out assets/data]
//
// Emits the roster index (`heroes.<locale>.json`) plus one detail file per
// Hero (`hero_<id>.<locale>.json`).
//
// The locale flag accepts any Valve feed language token (`english`,
// `russian`, `schinese`, …) so future UI languages can be snapshotted without
// code changes; v1 bundles English only.
//
// Fetching and conversion are both shared with the runtime refresh path
// (`HttpDatafeedClient`, `hero_feed_to_index.dart`, `hero_feed_to_detail.dart`),
// so a refreshed override is byte-shape compatible with the bundled asset by
// construction.

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/core/data/concurrent_map.dart';
import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_feed_to_detail.dart';
import 'package:dota2_guide/features/heroes/hero_feed_to_index.dart';

Future<void> main(List<String> arguments) async {
  final locale = _flagValue(arguments, '--locale') ?? 'english';
  final outDir = _flagValue(arguments, '--out') ?? 'assets/data';

  final feed = HttpDatafeedClient();

  stdout.writeln('Fetching herolist feed (language=$locale)…');
  final herolist = await feed.fetchJson(
    '$datafeedBaseUrl/herolist?language=$locale',
  );
  final index = heroIndexFromFeed(herolist, locale: locale);

  final heroes = index['heroes']! as List<Object?>;
  _writeJson('$outDir/heroes.$locale.json', index);
  stdout.writeln(
    'Emitted ${heroes.length} heroes → $outDir/heroes.$locale.json',
  );

  stdout.writeln('Fetching ${heroes.length} hero detail feeds…');
  final emitted = await mapConcurrently(
    heroes.cast<Map<String, Object?>>(),
    heroDetailFetchConcurrency,
    (hero) async {
      final heroId = hero['id']! as int;
      final detailFeed = await feed.fetchJson(
        heroDataFeedUrl(heroId, locale: locale),
      );
      final detail = heroDetailFromFeed(detailFeed, locale: locale);
      final file = File(
        '$outDir/${heroDetailUnitName(heroId, locale: locale)}',
      );
      _writeJson(file.path, detail);
      return MapEntry(heroId, file.path);
    },
  );

  stdout.writeln('Emitted ${emitted.length} hero details → $outDir/');
}

void _writeJson(String path, Map<String, Object?> json) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
}

String? _flagValue(List<String> arguments, String flag) {
  final index = arguments.indexOf(flag);
  if (index == -1) return null;
  if (index + 1 >= arguments.length) {
    throw FormatException('$flag requires a value');
  }
  return arguments[index + 1];
}
