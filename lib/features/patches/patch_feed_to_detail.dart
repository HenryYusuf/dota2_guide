// Valve patchnotes feed → app-schema patch detail.
//
// Converts the raw feed (`general_notes`, `items`, `heroes`, etc.) into
// structured sections with entity groups and indented change lines.

import 'patch_detail.dart';

Map<String, Object?> patchDetailFromFeed(
  Map<String, dynamic> feed, {
  required String locale,
  String? Function(int heroId)? heroNameLookup,
  String? Function(int heroId)? heroPortraitUrlLookup,
  String? Function(int itemId)? itemNameLookup,
  String? Function(int itemId)? itemIconUrlLookup,
}) {
  final patchNumber = _requiredString(feed, 'patch_number');
  final patchName = feed['patch_name']?.toString() ?? patchNumber;
  final timestamp = _requiredInt(feed, 'patch_timestamp');

  final sections = <Map<String, Object?>>[];

  // 1. General Notes
  final generalNotes = feed['general_notes'];
  if (generalNotes is List && generalNotes.isNotEmpty) {
    final groups = <Map<String, Object?>>[];
    for (final raw in generalNotes) {
      if (raw is! Map<String, dynamic>) continue;
      final title = raw['title']?.toString() ?? 'General Changes';
      final lines = _parseNotes(raw['generic']);
      if (lines.isNotEmpty) {
        groups.add({'title': title, 'lines': lines});
      }
    }
    if (groups.isNotEmpty) {
      sections.add({'title': 'General', 'groups': groups});
    }
  }

  // 2. Items
  final rawItems = feed['items'];
  if (rawItems is List && rawItems.isNotEmpty) {
    final groups = <Map<String, Object?>>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      final abilityId = _asInt(raw['ability_id']);
      if (abilityId == null) continue;
      final title = itemNameLookup?.call(abilityId) ?? 'Item $abilityId';
      final iconUrl = itemIconUrlLookup?.call(abilityId);
      final lines = _parseNotes(raw['ability_notes']);
      if (lines.isNotEmpty) {
        groups.add({
          'title': title,
          'item_id': abilityId,
          'icon_url': ?iconUrl,
          'lines': lines,
        });
      }
    }
    if (groups.isNotEmpty) {
      sections.add({'title': 'Items', 'groups': groups});
    }
  }

  // 3. Neutral Items
  final rawNeutrals = feed['neutral_items'];
  if (rawNeutrals is List && rawNeutrals.isNotEmpty) {
    final groups = <Map<String, Object?>>[];
    for (final raw in rawNeutrals) {
      if (raw is! Map<String, dynamic>) continue;
      final abilityId = _asInt(raw['ability_id']);
      final isGeneral =
          raw['is_general_note'] == true ||
          abilityId == -1 ||
          abilityId == null;

      if (isGeneral) {
        final title = raw['title']?.toString() ?? 'Neutral Item Changes';
        final lines = _parseNotes(raw['ability_notes']);
        groups.add({'title': title, 'lines': lines});
      } else {
        final title =
            itemNameLookup?.call(abilityId) ?? 'Neutral Item $abilityId';
        final iconUrl = itemIconUrlLookup?.call(abilityId);
        final lines = _parseNotes(raw['ability_notes']);
        if (lines.isNotEmpty) {
          groups.add({
            'title': title,
            'item_id': abilityId,
            'icon_url': ?iconUrl,
            'lines': lines,
          });
        }
      }
    }
    if (groups.isNotEmpty) {
      sections.add({'title': 'Neutral Items', 'groups': groups});
    }
  }

  // 4. Heroes
  final rawHeroes = feed['heroes'];
  if (rawHeroes is List && rawHeroes.isNotEmpty) {
    final groups = <Map<String, Object?>>[];
    for (final raw in rawHeroes) {
      if (raw is! Map<String, dynamic>) continue;
      final heroId = _asInt(raw['hero_id']);
      if (heroId == null) continue;
      final title = heroNameLookup?.call(heroId) ?? 'Hero $heroId';
      final iconUrl = heroPortraitUrlLookup?.call(heroId);

      final lines = <Map<String, Object?>>[..._parseNotes(raw['hero_notes'])];

      final abilities = raw['abilities'];
      if (abilities is List) {
        for (final rawAbility in abilities) {
          if (rawAbility is Map<String, dynamic>) {
            lines.addAll(_parseNotes(rawAbility['ability_notes']));
          }
        }
      }

      lines.addAll(_parseNotes(raw['talent_notes']));

      final subsections = raw['subsections'];
      if (subsections is List) {
        for (final rawSub in subsections) {
          if (rawSub is Map<String, dynamic>) {
            lines.addAll(
              _parseNotes(rawSub['ability_notes'] ?? rawSub['notes']),
            );
          }
        }
      }

      if (lines.isNotEmpty) {
        groups.add({
          'title': title,
          'hero_id': heroId,
          'icon_url': ?iconUrl,
          'lines': lines,
        });
      }
    }
    if (groups.isNotEmpty) {
      sections.add({'title': 'Heroes', 'groups': groups});
    }
  }

  // 5. Neutral Creeps
  final rawCreeps = feed['neutral_creeps'];
  if (rawCreeps is List && rawCreeps.isNotEmpty) {
    final groups = <Map<String, Object?>>[];
    for (final raw in rawCreeps) {
      if (raw is! Map<String, dynamic>) continue;
      final name =
          raw['localized_name']?.toString() ??
          raw['name']?.toString() ??
          'Neutral Creep';
      final lines = _parseNotes(raw['neutral_creep_notes']);
      if (lines.isNotEmpty) {
        groups.add({'title': name, 'lines': lines});
      }
    }
    if (groups.isNotEmpty) {
      sections.add({'title': 'Neutral Creeps', 'groups': groups});
    }
  }

  return {
    'schema_version': patchDetailSchemaVersion,
    'locale': locale,
    'patch_number': patchNumber,
    'patch_name': patchName,
    'timestamp': timestamp,
    'sections': sections,
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
  throw FormatException(
    'Patch detail feed: "$key" missing or not an int: $value',
  );
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException(
    'Patch detail feed: "$key" missing or not a string: $value',
  );
}
