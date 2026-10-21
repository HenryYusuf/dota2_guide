// Independent snapshot script: fetches pairwise hero matchup aggregates from OpenDota
// (/api/heroes/{id}/matchups) with a 1.2s rate throttle, compiling them into a compact
// bundled JSON matchup matrix for the offline Draft Picker (ADR-0002).
//
// Usage:
//   dart run tool/snapshot_matchups.dart [--out assets/data/hero_matchups.json] [--throttle-ms 1200] [--heroes-file assets/data/heroes.english.json]

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> arguments) async {
  final outPath =
      _flagValue(arguments, '--out') ?? 'assets/data/hero_matchups.json';
  final heroesFilePath =
      _flagValue(arguments, '--heroes-file') ??
      'assets/data/heroes.english.json';
  final throttleMsStr = _flagValue(arguments, '--throttle-ms') ?? '1200';
  final throttleMs = int.tryParse(throttleMsStr) ?? 1200;
  final heroIdsFilter = _flagValue(
    arguments,
    '--hero-ids',
  )?.split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toSet();

  stdout.writeln('Reading hero list from $heroesFilePath...');
  final heroesFile = File(heroesFilePath);
  if (!heroesFile.existsSync()) {
    stderr.writeln('Error: Heroes file not found at $heroesFilePath');
    exitCode = 1;
    return;
  }

  final heroesJson =
      jsonDecode(heroesFile.readAsStringSync()) as Map<String, dynamic>;
  final heroList = (heroesJson['heroes'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  final targetHeroes = heroList.where((h) {
    final id = h['id'] as int;
    return heroIdsFilter == null || heroIdsFilter.contains(id);
  }).toList();

  stdout.writeln(
    'Compiling matchup matrix for ${targetHeroes.length} heroes (throttle: ${throttleMs}ms)...',
  );

  final client = http.Client();
  final matrix = <String, Map<String, List<int>>>{};

  try {
    for (var i = 0; i < targetHeroes.length; i++) {
      final hero = targetHeroes[i];
      final heroId = hero['id'] as int;
      final heroName = hero['localized_name'] as String? ?? 'Hero $heroId';

      stdout.writeln(
        '[${i + 1}/${targetHeroes.length}] Fetching matchups for $heroName (ID: $heroId)...',
      );
      final url = Uri.parse(
        'https://api.opendota.com/api/heroes/$heroId/matchups',
      );

      http.Response response;
      try {
        response = await client.get(
          url,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'AegisCodex-SnapshotTool/1.0',
          },
        );
      } catch (e) {
        stderr.writeln(
          '  Warning: Request failed for hero $heroId ($heroName): $e',
        );
        continue;
      }

      if (response.statusCode != 200) {
        stderr.writeln(
          '  Warning: HTTP ${response.statusCode} for hero $heroId ($heroName)',
        );
      } else {
        try {
          final matchupsList = jsonDecode(response.body);
          if (matchupsList is List) {
            final opponentMap = <String, List<int>>{};
            for (final m in matchupsList) {
              if (m is Map<String, dynamic>) {
                final oppId = m['hero_id'];
                final games = m['games_played'];
                final wins = m['wins'];
                if (oppId != null && games is num && wins is num) {
                  opponentMap[oppId.toString()] = [wins.toInt(), games.toInt()];
                }
              }
            }
            matrix[heroId.toString()] = opponentMap;
          }
        } catch (e) {
          stderr.writeln(
            '  Warning: Failed to parse matchups for hero $heroId: $e',
          );
        }
      }

      if (i < targetHeroes.length - 1 && throttleMs > 0) {
        await Future.delayed(Duration(milliseconds: throttleMs));
      }
    }
  } finally {
    client.close();
  }

  stdout.writeln(
    'Writing ${matrix.length} hero matchup records to $outPath...',
  );
  final outFile = File(outPath);
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(jsonEncode(matrix));
  stdout.writeln(
    'Done! Output size: ${(outFile.lengthSync() / 1024).toStringAsFixed(1)} KB.',
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
