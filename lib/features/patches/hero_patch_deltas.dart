/// Structured patch delta models per hero across recent patches.
library;

import 'patch_detail.dart';

const int heroPatchDeltasSchemaVersion = 1;

String heroPatchDeltasUnitName({String locale = 'english'}) =>
    'hero_patch_deltas.$locale.json';

String heroPatchDeltasAssetPath({String locale = 'english'}) =>
    'assets/data/${heroPatchDeltasUnitName(locale: locale)}';

class HeroAbilityPatchDelta {
  const HeroAbilityPatchDelta({
    required this.abilityId,
    this.abilityName,
    required this.lines,
  });

  factory HeroAbilityPatchDelta.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final lines = rawLines is List
        ? rawLines
              .whereType<Map<String, dynamic>>()
              .map(PatchChangeLine.fromJson)
              .toList(growable: false)
        : const <PatchChangeLine>[];

    return HeroAbilityPatchDelta(
      abilityId: _requiredInt(json, 'ability_id'),
      abilityName: json['ability_name'] as String?,
      lines: lines,
    );
  }

  final int abilityId;
  final String? abilityName;
  final List<PatchChangeLine> lines;

  Map<String, Object?> toJson() => {
    'ability_id': abilityId,
    if (abilityName != null) 'ability_name': abilityName,
    'lines': lines.map((l) => l.toJson()).toList(growable: false),
  };
}

class HeroPatchDelta {
  const HeroPatchDelta({
    required this.patchNumber,
    required this.patchName,
    required this.timestamp,
    required this.stats,
    required this.talents,
    required this.abilities,
  });

  factory HeroPatchDelta.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    final rawTalents = json['talents'];
    final rawAbilities = json['abilities'];

    return HeroPatchDelta(
      patchNumber: _requiredString(json, 'patch_number'),
      patchName:
          json['patch_name']?.toString() ?? json['patch_number'].toString(),
      timestamp: _requiredInt(json, 'timestamp'),
      stats: rawStats is List
          ? rawStats
                .whereType<Map<String, dynamic>>()
                .map(PatchChangeLine.fromJson)
                .toList(growable: false)
          : const <PatchChangeLine>[],
      talents: rawTalents is List
          ? rawTalents
                .whereType<Map<String, dynamic>>()
                .map(PatchChangeLine.fromJson)
                .toList(growable: false)
          : const <PatchChangeLine>[],
      abilities: rawAbilities is List
          ? rawAbilities
                .whereType<Map<String, dynamic>>()
                .map(HeroAbilityPatchDelta.fromJson)
                .toList(growable: false)
          : const <HeroAbilityPatchDelta>[],
    );
  }

  final String patchNumber;
  final String patchName;
  final int timestamp;
  final List<PatchChangeLine> stats;
  final List<PatchChangeLine> talents;
  final List<HeroAbilityPatchDelta> abilities;

  DateTime get releaseDate =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  Map<String, Object?> toJson() => {
    'patch_number': patchNumber,
    'patch_name': patchName,
    'timestamp': timestamp,
    'stats': stats.map((l) => l.toJson()).toList(growable: false),
    'talents': talents.map((l) => l.toJson()).toList(growable: false),
    'abilities': abilities.map((a) => a.toJson()).toList(growable: false),
  };
}

class HeroAbilityDeltaRecord {
  const HeroAbilityDeltaRecord({
    required this.patchNumber,
    required this.timestamp,
    required this.lines,
  });

  final String patchNumber;
  final int timestamp;
  final List<PatchChangeLine> lines;
}

class HeroPatchHistory {
  const HeroPatchHistory({required this.heroId, required this.deltas});

  factory HeroPatchHistory.fromJson(int heroId, Map<String, dynamic> json) {
    final rawDeltas = json['deltas'];
    return HeroPatchHistory(
      heroId: heroId,
      deltas: rawDeltas is List
          ? rawDeltas
                .whereType<Map<String, dynamic>>()
                .map(HeroPatchDelta.fromJson)
                .toList(growable: false)
          : const <HeroPatchDelta>[],
    );
  }

  final int heroId;
  final List<HeroPatchDelta> deltas;

  bool get hasChanges => deltas.isNotEmpty;

  List<HeroAbilityDeltaRecord> deltasForAbility(String abilityName) {
    final records = <HeroAbilityDeltaRecord>[];
    for (final delta in deltas) {
      for (final ability in delta.abilities) {
        if (ability.abilityName != null && ability.abilityName == abilityName) {
          records.add(
            HeroAbilityDeltaRecord(
              patchNumber: delta.patchNumber,
              timestamp: delta.timestamp,
              lines: ability.lines,
            ),
          );
        }
      }
    }
    return records;
  }

  String? latestPatchForAbility(String abilityName) {
    final abilityDeltas = deltasForAbility(abilityName);
    if (abilityDeltas.isEmpty) return null;
    return abilityDeltas.first.patchNumber;
  }
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException(
    'Hero patch delta: "$key" missing or not an int: $value',
  );
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException(
    'Hero patch delta: "$key" missing or not a string: $value',
  );
}
