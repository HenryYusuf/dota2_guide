// Snapshot tool: fetches Valve's official key-free datafeeds once and emits
// app-schema JSON into the assets the app bundles, so the app is fully usable
// offline on first launch (ADR-0001: datafeeds only, never KV extraction).
//
// Usage:
//   dart run tool/snapshot.dart [--validate] [--locale english] [--out assets/data] [--heroes-only] [--items-only] [--patches-only]
//
// Modes:
//   (default): fetches official feeds and emits/overwrites app-schema JSON
//              into the bundled assets directory.
//   --validate: re-pulls official feeds, diffs their schema shape against
//               the committed snapshot without writing files, and exits non-zero
//               on drift with a detailed report (pre-release release gate).
//
// Emits the roster index (`heroes.<locale>.json`) plus one detail file per
// Hero (`hero_<id>.<locale>.json`), the Item index (`items.<locale>.json`)
// plus one detail file per listable Item (`item_<id>.<locale>.json`), and the
// Patch index (`patches.<locale>.json`) plus the latest Patch detail file
// (`patch_<patchNumber>.<locale>.json`).
//
// The locale flag accepts any Valve feed language token (`english`,
// `russian`, `schinese`, …) so future UI languages can be snapshotted without
// code changes; v1 bundles English only.
//
// Fetching and conversion are both shared with the runtime refresh path
// (`HttpDatafeedClient`, `hero_feed_to_index.dart`, `hero_feed_to_detail.dart`,
// `item_feed_to_index.dart`, `item_feed_to_detail.dart`), so a refreshed
// override is byte-shape compatible with the bundled asset by construction.

import 'dart:convert';
import 'dart:io';

import 'package:dota2_guide/core/data/concurrent_map.dart';
import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/features/heroes/hero_detail.dart';
import 'package:dota2_guide/features/heroes/hero_feed_to_detail.dart';
import 'package:dota2_guide/features/heroes/hero_feed_to_index.dart';
import 'package:dota2_guide/features/heroes/hero_index.dart';
import 'package:dota2_guide/features/items/item_detail.dart';
import 'package:dota2_guide/features/items/item_feed_to_detail.dart';
import 'package:dota2_guide/features/items/item_feed_to_index.dart';
import 'package:dota2_guide/features/items/item_index.dart';
import 'package:dota2_guide/features/patches/hero_patch_inverter.dart';
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patch_feed_to_detail.dart';
import 'package:dota2_guide/features/patches/patch_feed_to_index.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';

import 'schema_validator.dart';

Future<void> main(List<String> arguments) async {
  final locale = _flagValue(arguments, '--locale') ?? 'english';
  final outDir = _flagValue(arguments, '--out') ?? 'assets/data';
  final heroesOnly = arguments.contains('--heroes-only');
  final itemsOnly = arguments.contains('--items-only');
  final patchesOnly = arguments.contains('--patches-only');
  final isValidate = arguments.contains('--validate');

  final feed = HttpDatafeedClient();

  if (isValidate) {
    stdout.writeln(
      'Validating official datafeeds against committed snapshot in $outDir ($locale)...',
    );
    final report = await validateSnapshot(
      feed: feed,
      snapshotDir: outDir,
      locale: locale,
      heroesOnly: heroesOnly,
      itemsOnly: itemsOnly,
      patchesOnly: patchesOnly,
      onProgress: stdout.writeln,
    );
    stdout.write(report.formatReport());
    if (report.hasDrift) {
      exitCode = 1;
    }
    return;
  }

  if (!itemsOnly && !patchesOnly) {
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

  if (!heroesOnly && !patchesOnly) {
    stdout.writeln('Fetching itemlist feed (language=$locale)…');
    final itemlist = await feed.fetchJson(
      '$datafeedBaseUrl/itemlist?language=$locale',
    );
    final itemIndex = itemIndexFromFeed(itemlist, locale: locale);

    final items = itemIndex['items']! as List<Object?>;
    _writeJson('$outDir/items.$locale.json', itemIndex);
    stdout.writeln(
      'Emitted ${items.length} items → $outDir/items.$locale.json',
    );

    stdout.writeln('Fetching item detail feeds…');
    final entries = itemlistEntries(itemlist, locale: locale);
    final docsByKey = Map.fromEntries(
      await mapConcurrently(entries, itemDetailFetchConcurrency, (entry) async {
        final valveKey = entry['name'] as String;
        final id = (entry['id'] as num).toInt();
        final detailFeed = await feed.fetchJson(
          itemDataFeedUrl(id, locale: locale),
        );
        return MapEntry(valveKey, detailFeed);
      }),
    );
    final costs = <String, int>{
      for (final (valveKey, cost) in docsByKey.values.map(
        (doc) => itemCostFromFeed(doc, locale: locale),
      ))
        valveKey: cost,
    };
    final recipes = itemRecipesFromItemlist(entries, costs);
    final parsedIndex = ItemIndex.fromJson(itemIndex);
    var emittedCount = 0;
    for (final item in parsedIndex.items) {
      if (!item.isListable) continue;
      final detail = itemDetailFromFeed(
        docsByKey[item.valveKey]!,
        locale: locale,
        recipe: recipes[item.valveKey],
      );
      final file = File(
        '$outDir/${itemDetailUnitName(item.id, locale: locale)}',
      );
      _writeJson(file.path, detail);
      emittedCount++;
    }

    stdout.writeln('Emitted $emittedCount item details → $outDir/');
  }

  if (!heroesOnly && !itemsOnly) {
    stdout.writeln('Fetching patchnoteslist feed (language=$locale)…');
    final patchnoteslist = await feed.fetchJson(
      '$datafeedBaseUrl/patchnoteslist?language=$locale',
    );
    final patchIndex = patchIndexFromFeed(patchnoteslist, locale: locale);
    final patches = patchIndex['patches']! as List<Object?>;
    _writeJson('$outDir/patches.$locale.json', patchIndex);
    stdout.writeln(
      'Emitted ${patches.length} patches → $outDir/patches.$locale.json',
    );

    final parsedIndex = PatchIndex.fromJson(patchIndex);
    final latest = parsedIndex.latestPatch;
    if (latest != null) {
      stdout.writeln(
        'Fetching latest patch (${latest.patchNumber}) detail feed…',
      );
      HeroIndex? heroIndex;
      final heroesFile = File('$outDir/heroes.$locale.json');
      if (heroesFile.existsSync()) {
        heroIndex = HeroIndex.fromJson(
          jsonDecode(heroesFile.readAsStringSync()) as Map<String, dynamic>,
        );
      } else {
        final herolist = await feed.fetchJson(
          '$datafeedBaseUrl/herolist?language=$locale',
        );
        heroIndex = HeroIndex.fromJson(
          heroIndexFromFeed(herolist, locale: locale),
        );
      }
      ItemIndex? itemIndex;
      final itemsFile = File('$outDir/items.$locale.json');
      if (itemsFile.existsSync()) {
        itemIndex = ItemIndex.fromJson(
          jsonDecode(itemsFile.readAsStringSync()) as Map<String, dynamic>,
        );
      } else {
        final itemlist = await feed.fetchJson(
          '$datafeedBaseUrl/itemlist?language=$locale',
        );
        itemIndex = ItemIndex.fromJson(
          itemIndexFromFeed(itemlist, locale: locale),
        );
      }
      final heroMap = {for (final h in heroIndex.heroes) h.id: h};
      final itemMap = {for (final i in itemIndex.items) i.id: i};

      final detailFeed = await feed.fetchJson(
        '$datafeedBaseUrl/patchnotes?version=${latest.patchNumber}&language=$locale',
      );
      final detail = patchDetailFromFeed(
        detailFeed,
        locale: locale,
        heroNameLookup: (id) => heroMap[id]?.localizedName,
        heroPortraitUrlLookup: (id) => heroMap[id]?.portraitUrl,
        itemNameLookup: (id) => itemMap[id]?.name,
        itemIconUrlLookup: (id) => itemMap[id]?.iconUrl,
      );
      final file = File(
        '$outDir/${patchDetailUnitName(latest.patchNumber, locale: locale)}',
      );
      _writeJson(file.path, detail);
      stdout.writeln('Emitted latest patch detail → ${file.path}');
    }

    final recentPatches = parsedIndex.patches.take(5).toList();
    if (recentPatches.isNotEmpty) {
      stdout.writeln(
        'Fetching recent ${recentPatches.length} patch feeds for hero patch history…',
      );
      final rawPatchFeeds = <Map<String, dynamic>>[];
      for (final p in recentPatches) {
        final feedDoc = await feed.fetchJson(
          '$datafeedBaseUrl/patchnotes?version=${p.patchNumber}&language=$locale',
        );
        rawPatchFeeds.add(feedDoc);
      }

      final changedHeroIds = <int>{};
      for (final f in rawPatchFeeds) {
        final heroes = f['heroes'] as List? ?? [];
        for (final h in heroes) {
          if (h is Map<String, dynamic> && h['hero_id'] is num) {
            changedHeroIds.add((h['hero_id'] as num).toInt());
          }
        }
      }

      final heroAbilityMap = <int, Map<int, String>>{};
      await mapConcurrently(
        changedHeroIds.toList(),
        heroDetailFetchConcurrency,
        (heroId) async {
          final heroFeed = await feed.fetchJson(
            heroDataFeedUrl(heroId, locale: locale),
          );
          final heroes =
              (heroFeed['result']?['data']?['heroes'] as List?) ?? [];
          if (heroes.isNotEmpty) {
            final hero = heroes.first as Map<String, dynamic>;
            final abilities = hero['abilities'] as List? ?? [];
            final map = <int, String>{};
            for (final a in abilities) {
              if (a is Map<String, dynamic> &&
                  a['id'] is num &&
                  a['name'] is String) {
                map[(a['id'] as num).toInt()] = a['name'] as String;
              }
            }
            heroAbilityMap[heroId] = map;
          }
          return heroId;
        },
      );

      final inverted = invertPatchHistory(
        rawPatchFeeds: rawPatchFeeds,
        heroAbilityMap: heroAbilityMap,
        locale: locale,
      );
      _writeJson('$outDir/hero_patch_deltas.$locale.json', inverted);
      stdout.writeln(
        'Emitted hero patch history → $outDir/hero_patch_deltas.$locale.json',
      );
    }
  }
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
