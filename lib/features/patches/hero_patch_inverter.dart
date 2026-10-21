/// Inverts patch notes feeds into a bundled dataset indexed by hero ID.
library;

/// Inverts a list of raw patch feeds across multiple patches into a Map indexed by hero ID.
Map<String, Object?> invertPatchHistory({
  required List<Map<String, dynamic>> rawPatchFeeds,
  required Map<int, Map<int, String>> heroAbilityMap,
  required String locale,
  int schemaVersion = 1,
}) {
  // Sort feeds newest first
  final sortedFeeds = List<Map<String, dynamic>>.from(rawPatchFeeds)
    ..sort((a, b) {
      final tA = _asInt(a['patch_timestamp']) ?? 0;
      final tB = _asInt(b['patch_timestamp']) ?? 0;
      return tB.compareTo(tA);
    });

  final heroesMap = <String, Map<String, Object?>>{};

  for (final feed in sortedFeeds) {
    final patchNumber = _requiredString(feed, 'patch_number');
    final patchName = feed['patch_name']?.toString() ?? patchNumber;
    final timestamp = _requiredInt(feed, 'patch_timestamp');

    final rawHeroes = feed['heroes'];
    if (rawHeroes is! List) continue;

    for (final rawHero in rawHeroes) {
      if (rawHero is! Map<String, dynamic>) continue;
      final heroId = _asInt(rawHero['hero_id']);
      if (heroId == null) continue;

      final heroKey = heroId.toString();
      final statsLines = _parseNotes(rawHero['hero_notes']);
      final talentLines = _parseNotes(rawHero['talent_notes']);

      final abilityDeltas = <Map<String, Object?>>[];
      final rawAbilities = rawHero['abilities'];
      if (rawAbilities is List) {
        for (final rawAbility in rawAbilities) {
          if (rawAbility is! Map<String, dynamic>) continue;
          final abilityId = _asInt(rawAbility['ability_id']);
          if (abilityId == null) continue;

          final abilityLines = _parseNotes(rawAbility['ability_notes']);
          if (abilityLines.isEmpty) continue;

          final abilityName =
              heroAbilityMap[heroId]?[abilityId] ??
              rawAbility['ability_name']?.toString();

          abilityDeltas.add({
            'ability_id': abilityId,
            'ability_name': ?abilityName,
            'lines': abilityLines,
          });
        }
      }

      if (statsLines.isEmpty && talentLines.isEmpty && abilityDeltas.isEmpty) {
        continue;
      }

      final delta = <String, Object?>{
        'patch_number': patchNumber,
        'patch_name': patchName,
        'timestamp': timestamp,
        'stats': statsLines,
        'talents': talentLines,
        'abilities': abilityDeltas,
      };

      final heroRecord = heroesMap.putIfAbsent(
        heroKey,
        () => {'hero_id': heroId, 'deltas': <Map<String, Object?>>[]},
      );

      (heroRecord['deltas']! as List<Map<String, Object?>>).add(delta);
    }
  }

  return {
    'schema_version': schemaVersion,
    'locale': locale,
    'heroes': heroesMap,
  };
}

List<Map<String, Object?>> _parseNotes(Object? rawNotes) {
  final lines = <Map<String, Object?>>[];
  if (rawNotes is List) {
    for (final rawNote in rawNotes) {
      if (rawNote is! Map<String, dynamic>) continue;
      final line = _parseLine(rawNote);
      if (line != null) lines.add(line);
    }
  }
  return lines;
}

Map<String, Object?>? _parseLine(Map<String, dynamic> rawNote) {
  final noteRaw = rawNote['note']?.toString();
  if (noteRaw == null) return null;
  final cleaned = _cleanNote(noteRaw);
  if (cleaned.isEmpty) return null;

  final indentLevel = _asInt(rawNote['indent_level']) ?? 1;
  final aghanims = rawNote['aghanims']?.toString();

  return {
    'text': cleaned,
    'indent_level': indentLevel,
    if (aghanims != null && aghanims.isNotEmpty) 'badge': aghanims,
  };
}

String _cleanNote(String text) => text
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
    .replaceAll(r'<\/>', '</')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Feed: "$key" missing or not an int: $value');
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('Feed: "$key" missing or not a string: $value');
}
