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
//
// Fetching and conversion are both shared with the runtime refresh path
// (`HttpDatafeedClient`, `hero_feed_to_index.dart`), so a refreshed override
// is byte-shape compatible with the bundled asset by construction.

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/features/heroes/hero_feed_to_index.dart';

Future<void> main(List<String> arguments) async {
  final locale = _flagValue(arguments, '--locale') ?? 'english';
  final outDir = _flagValue(arguments, '--out') ?? 'assets/data';

  stdout.writeln('Fetching herolist feed (language=$locale)…');
  final feed = await HttpDatafeedClient().fetchJson(
    '$datafeedBaseUrl/herolist?language=$locale',
  );
  final index = heroIndexFromFeed(feed, locale: locale);

  final heroes = index['heroes']! as List<Object?>;
  final outFile = File('$outDir/heroes.$locale.json');
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(index)}\n',
  );

  stdout.writeln('Emitted ${heroes.length} heroes → ${outFile.path}');
}

String? _flagValue(List<String> arguments, String flag) {
  final index = arguments.indexOf(flag);
  if (index == -1) return null;
  if (index + 1 >= arguments.length) {
    throw FormatException('$flag requires a value');
  }
  return arguments[index + 1];
}
