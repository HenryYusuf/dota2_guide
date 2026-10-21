// Schema validator: compares the schema shape of newly pulled/converted
// datafeed objects against the committed snapshot, detecting Valve-side drift
// before a release (ADR-0001, User Story 42, Issue 11).

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
import 'package:dota2_guide/features/patches/patch_detail.dart';
import 'package:dota2_guide/features/patches/patch_feed_to_detail.dart';
import 'package:dota2_guide/features/patches/patch_feed_to_index.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';

class SchemaDrift {
  final String path;
  final String message;

  const SchemaDrift(this.path, this.message);

  @override
  String toString() => '$path: $message';
}

class ValidationReport {
  final Map<String, List<SchemaDrift>> driftsByFile = {};
  final List<String> errors = [];
  int validatedFilesCount = 0;

  bool get hasDrift => driftsByFile.isNotEmpty || errors.isNotEmpty;

  void addDrifts(String file, List<SchemaDrift> drifts) {
    if (drifts.isNotEmpty) {
      driftsByFile.putIfAbsent(file, () => []).addAll(drifts);
    }
  }

  void addError(String error) {
    errors.add(error);
  }

  String formatReport() {
    final buffer = StringBuffer();
    if (hasDrift) {
      buffer.writeln('==================================================');
      buffer.writeln('SCHEMA DRIFT DETECTED');
      buffer.writeln('==================================================');
      if (errors.isNotEmpty) {
        buffer.writeln('Feed conversion errors:');
        for (final error in errors) {
          buffer.writeln('  - $error');
        }
        buffer.writeln();
      }
      if (driftsByFile.isNotEmpty) {
        buffer.writeln('Schema shape drifts:');
        for (final entry in driftsByFile.entries) {
          buffer.writeln('[DRIFT] ${entry.key}:');
          for (final drift in entry.value) {
            buffer.writeln('  - $drift');
          }
          buffer.writeln();
        }
      }
      final totalDrifts = driftsByFile.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      buffer.writeln(
        'Found $totalDrifts drift issue(s) and ${errors.length} error(s).',
      );
      buffer.writeln('==================================================');
    } else {
      buffer.writeln('==================================================');
      buffer.writeln('SCHEMA VALIDATION PASSED');
      buffer.writeln('==================================================');
      buffer.writeln(
        'Validated $validatedFilesCount snapshot file(s) against live datafeeds.',
      );
      buffer.writeln('No schema drift detected.');
      buffer.writeln('==================================================');
    }
    return buffer.toString();
  }
}

const Set<String> _optionalFields = {
  'lore',
  'notes',
  'granted_by',
  'behavior_tag',
  'target',
  'pierces_spell_immunity',
  'damage_type',
  'dispellable',
  'damages',
  'scepter_text',
  'shard_text',
  'neutral_tier',
  'combination_cost',
  'hero_id',
  'item_id',
  'badge',
};

/// Diffs the schema shape of [candidate] against [committed].
List<SchemaDrift> diffSchemaShape(
  Object? candidate,
  Object? committed, {
  String path = r'$',
}) {
  final drifts = <SchemaDrift>[];

  if (committed == null && candidate == null) {
    return drifts;
  }

  if (committed == null) {
    return drifts;
  }

  if (candidate == null) {
    drifts.add(
      SchemaDrift(
        path,
        'type mismatch: expected ${_typeName(committed)}, got null',
      ),
    );
    return drifts;
  }

  if (!_typesCompatible(candidate, committed)) {
    drifts.add(
      SchemaDrift(
        path,
        'type mismatch: expected ${_typeName(committed)}, got ${_typeName(candidate)} ($candidate)',
      ),
    );
    return drifts;
  }

  if (committed is Map && candidate is Map) {
    final committedMap = committed.cast<String, Object?>();
    final candidateMap = candidate.cast<String, Object?>();

    for (final key in committedMap.keys) {
      if (!candidateMap.containsKey(key)) {
        if (!_optionalFields.contains(key)) {
          drifts.add(
            SchemaDrift(
              path == r'$' ? r'$.' + key : '$path.$key',
              'missing key "$key"',
            ),
          );
        }
      }
    }

    for (final key in candidateMap.keys) {
      if (!committedMap.containsKey(key)) {
        if (!_optionalFields.contains(key)) {
          drifts.add(
            SchemaDrift(
              path == r'$' ? r'$.' + key : '$path.$key',
              'unexpected field "$key"',
            ),
          );
        }
      }
    }

    for (final entry in candidateMap.entries) {
      if (committedMap.containsKey(entry.key)) {
        final subPath = path == r'$' ? r'$.' + entry.key : '$path.${entry.key}';
        drifts.addAll(
          diffSchemaShape(entry.value, committedMap[entry.key], path: subPath),
        );
      }
    }
  } else if (committed is List && candidate is List) {
    if (committed.isNotEmpty &&
        candidate.isEmpty &&
        (path == r'$.heroes' || path == r'$.items' || path == r'$.patches')) {
      drifts.add(
        SchemaDrift(
          path,
          'empty entity list in candidate where committed has ${committed.length} element(s)',
        ),
      );
    } else if (committed.isNotEmpty) {
      final template = committed.first;
      for (var i = 0; i < candidate.length; i++) {
        final reference = i < committed.length ? committed[i] : template;
        drifts.addAll(
          diffSchemaShape(candidate[i], reference, path: '$path[$i]'),
        );
      }
    }
  }

  return drifts;
}

String _typeName(Object? val) {
  if (val == null) return 'null';
  if (val is bool) return 'bool';
  if (val is int) return 'int';
  if (val is double) return 'double';
  if (val is num) return 'num';
  if (val is String) return 'String';
  if (val is List) return 'List';
  if (val is Map) return 'Map';
  return val.runtimeType.toString();
}

bool _typesCompatible(Object? a, Object? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a is num && b is num) return true;
  if (a is String && b is String) return true;
  if (a is bool && b is bool) return true;
  if (a is List && b is List) return true;
  if (a is Map && b is Map) return true;
  return false;
}

/// Validates live feeds against committed snapshot files in [snapshotDir].
Future<ValidationReport> validateSnapshot({
  required DatafeedClient feed,
  required String snapshotDir,
  String locale = 'english',
  bool heroesOnly = false,
  bool itemsOnly = false,
  bool patchesOnly = false,
  int? sampleHeroDetails,
  int? sampleItemDetails,
  void Function(String message)? onProgress,
}) async {
  final report = ValidationReport();

  Map<String, dynamic>? readCommitted(String filename) {
    final file = File('$snapshotDir/$filename');
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      report.addError('Failed to parse committed snapshot $filename: $e');
      return null;
    }
  }

  // 1. Heroes
  if (!itemsOnly && !patchesOnly) {
    onProgress?.call('Validating heroes feed ($locale)...');
    try {
      final herolist = await feed.fetchJson(
        '$datafeedBaseUrl/herolist?language=$locale',
      );
      final index = heroIndexFromFeed(herolist, locale: locale);
      final committedIndex = readCommitted('heroes.$locale.json');
      if (committedIndex != null) {
        final drifts = diffSchemaShape(index, committedIndex);
        report.addDrifts('heroes.$locale.json', drifts);
        report.validatedFilesCount++;
        try {
          HeroIndex.fromJson(index);
        } catch (e) {
          report.addError('heroes.$locale.json HeroIndex.fromJson failed: $e');
        }
      } else {
        report.addError('Missing committed snapshot file: heroes.$locale.json');
      }

      final heroes = (index['heroes'] as List? ?? [])
          .cast<Map<String, Object?>>();
      final toCheck = sampleHeroDetails != null
          ? heroes.take(sampleHeroDetails).toList()
          : heroes;

      onProgress?.call('Validating ${toCheck.length} hero details...');
      await mapConcurrently(toCheck, heroDetailFetchConcurrency, (hero) async {
        final heroId = hero['id']! as int;
        final unitName = heroDetailUnitName(heroId, locale: locale);
        try {
          final detailFeed = await feed.fetchJson(
            heroDataFeedUrl(heroId, locale: locale),
          );
          final detail = heroDetailFromFeed(detailFeed, locale: locale);
          final committed = readCommitted(unitName);
          if (committed != null) {
            final drifts = diffSchemaShape(detail, committed);
            report.addDrifts(unitName, drifts);
            report.validatedFilesCount++;
            try {
              HeroDetail.fromJson(detail);
            } catch (e) {
              report.addError('$unitName HeroDetail.fromJson failed: $e');
            }
          } else {
            report.addError('Missing committed snapshot file: $unitName');
          }
        } catch (e) {
          report.addError('$unitName conversion/fetch failed: $e');
        }
      });
    } catch (e) {
      report.addError('Heroes validation error: $e');
    }
  }

  // 2. Items
  if (!heroesOnly && !patchesOnly) {
    onProgress?.call('Validating items feed ($locale)...');
    try {
      final itemlist = await feed.fetchJson(
        '$datafeedBaseUrl/itemlist?language=$locale',
      );
      final itemIndex = itemIndexFromFeed(itemlist, locale: locale);
      final committedItemIndex = readCommitted('items.$locale.json');
      if (committedItemIndex != null) {
        final drifts = diffSchemaShape(itemIndex, committedItemIndex);
        report.addDrifts('items.$locale.json', drifts);
        report.validatedFilesCount++;
        try {
          ItemIndex.fromJson(itemIndex);
        } catch (e) {
          report.addError('items.$locale.json ItemIndex.fromJson failed: $e');
        }
      } else {
        report.addError('Missing committed snapshot file: items.$locale.json');
      }

      final entries = itemlistEntries(itemlist, locale: locale);
      final docsByKey = Map.fromEntries(
        await mapConcurrently(entries, itemDetailFetchConcurrency, (
          entry,
        ) async {
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

      final listableItems = parsedIndex.items
          .where((i) => i.isListable)
          .toList();
      final toCheck = sampleItemDetails != null
          ? listableItems.take(sampleItemDetails).toList()
          : listableItems;

      onProgress?.call('Validating ${toCheck.length} item details...');
      for (final item in toCheck) {
        final unitName = itemDetailUnitName(item.id, locale: locale);
        try {
          final detail = itemDetailFromFeed(
            docsByKey[item.valveKey]!,
            locale: locale,
            recipe: recipes[item.valveKey],
          );
          final committed = readCommitted(unitName);
          if (committed != null) {
            final drifts = diffSchemaShape(detail, committed);
            report.addDrifts(unitName, drifts);
            report.validatedFilesCount++;
            try {
              ItemDetail.fromJson(detail);
            } catch (e) {
              report.addError('$unitName ItemDetail.fromJson failed: $e');
            }
          } else {
            report.addError('Missing committed snapshot file: $unitName');
          }
        } catch (e) {
          report.addError('$unitName conversion/fetch failed: $e');
        }
      }
    } catch (e) {
      report.addError('Items validation error: $e');
    }
  }

  // 3. Patches
  if (!heroesOnly && !itemsOnly) {
    onProgress?.call('Validating patches feed ($locale)...');
    try {
      final patchnoteslist = await feed.fetchJson(
        '$datafeedBaseUrl/patchnoteslist?language=$locale',
      );
      final patchIndex = patchIndexFromFeed(patchnoteslist, locale: locale);
      final committedPatchIndex = readCommitted('patches.$locale.json');
      if (committedPatchIndex != null) {
        final drifts = diffSchemaShape(patchIndex, committedPatchIndex);
        report.addDrifts('patches.$locale.json', drifts);
        report.validatedFilesCount++;
        try {
          PatchIndex.fromJson(patchIndex);
        } catch (e) {
          report.addError(
            'patches.$locale.json PatchIndex.fromJson failed: $e',
          );
        }
      } else {
        report.addError(
          'Missing committed snapshot file: patches.$locale.json',
        );
      }

      final parsedPatchIndex = PatchIndex.fromJson(patchIndex);
      final latest = parsedPatchIndex.latestPatch;
      if (latest != null) {
        final unitName = patchDetailUnitName(
          latest.patchNumber,
          locale: locale,
        );
        onProgress?.call(
          'Validating latest patch (${latest.patchNumber}) detail...',
        );

        final heroesFile = File('$snapshotDir/heroes.$locale.json');
        HeroIndex? heroIdx;
        if (heroesFile.existsSync()) {
          heroIdx = HeroIndex.fromJson(
            jsonDecode(heroesFile.readAsStringSync()) as Map<String, dynamic>,
          );
        }
        final itemsFile = File('$snapshotDir/items.$locale.json');
        ItemIndex? itemIdx;
        if (itemsFile.existsSync()) {
          itemIdx = ItemIndex.fromJson(
            jsonDecode(itemsFile.readAsStringSync()) as Map<String, dynamic>,
          );
        }
        final heroMap = {
          for (final h in heroIdx?.heroes ?? <HeroSummary>[]) h.id: h,
        };
        final itemMap = {
          for (final i in itemIdx?.items ?? <ItemSummary>[]) i.id: i,
        };

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

        final committed = readCommitted(unitName);
        if (committed != null) {
          final drifts = diffSchemaShape(detail, committed);
          report.addDrifts(unitName, drifts);
          report.validatedFilesCount++;
          try {
            PatchDetail.fromJson(detail);
          } catch (e) {
            report.addError('$unitName PatchDetail.fromJson failed: $e');
          }
        } else {
          report.addError('Missing committed snapshot file: $unitName');
        }
      }
    } catch (e) {
      report.addError('Patches validation error: $e');
    }
  }

  return report;
}
