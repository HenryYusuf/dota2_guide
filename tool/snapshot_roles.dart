// Snapshot tool for hero roles: fetches Valve's official herodata feed for each hero
// and extracts role_levels, compiling them into a compact bundled JSON file
// for the offline Draft Picker composition diagnostics and position filtering.
//
// Usage:
//   dart run tool/snapshot_roles.dart [--out assets/data/hero_roles.json] [--heroes-file assets/data/heroes.english.json]

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> arguments) async {
  final outPath =
      _flagValue(arguments, '--out') ?? 'assets/data/hero_roles.json';
  final heroesFilePath =
      _flagValue(arguments, '--heroes-file') ??
      'assets/data/heroes.english.json';

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

  stdout.writeln(
    'Fetching role_levels for ${heroList.length} heroes from Valve datafeed...',
  );

  final client = http.Client();
  final rolesMap = <String, List<int>>{};

  try {
    // Valve datafeed has no strict rate limit; fetch with modest concurrency
    final total = heroList.length;
    var completed = 0;

    // Process in batches of 10
    const batchSize = 10;
    for (var i = 0; i < heroList.length; i += batchSize) {
      final batch = heroList.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((hero) async {
          final heroId = hero['id'] as int;
          final url = Uri.parse(
            'https://www.dota2.com/datafeed/herodata?language=english&hero_id=$heroId',
          );
          final response = await client.get(url);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final heroesArray =
                data['result']?['data']?['heroes'] as List<dynamic>?;
            if (heroesArray != null && heroesArray.isNotEmpty) {
              final heroData = heroesArray[0] as Map<String, dynamic>;
              final rawRoleLevels = heroData['role_levels'] as List<dynamic>?;
              if (rawRoleLevels != null) {
                rolesMap[heroId.toString()] = rawRoleLevels
                    .map((v) => (v as num).toInt())
                    .toList();
              }
            }
          }
          completed++;
        }),
      );
      stdout.write('\rProgress: $completed/$total heroes fetched');
    }
    stdout.writeln(
      '\nSuccessfully fetched role levels for ${rolesMap.length} heroes.',
    );

    final outFile = File(outPath);
    final encoder = const JsonEncoder.withIndent('  ');
    await outFile.writeAsString(encoder.convert(rolesMap));
    stdout.writeln('Saved to $outPath (${outFile.lengthSync()} bytes)');
  } finally {
    client.close();
  }
}

String? _flagValue(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index != -1 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}
