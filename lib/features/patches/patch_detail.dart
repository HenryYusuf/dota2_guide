/// Patch detail: the app schema for one Patch's structured change notes.
///
/// The contract is the FILE, not this class: `dart run tool/snapshot.dart`
/// emits `assets/data/patch_<patchNumber>.<locale>.json` and
/// `test/features/patches/patch_detail_test.dart` parses that real file to pin
/// the schema.
library;

/// Current schema version of the emitted patch-detail file.
const int patchDetailSchemaVersion = 1;

/// Asset path for one bundled Patch detail file.
String patchDetailAssetPath(String patchNumber, {String locale = 'english'}) =>
    'assets/data/${patchDetailUnitName(patchNumber, locale: locale)}';

/// Unit name for override storage.
String patchDetailUnitName(String patchNumber, {String locale = 'english'}) =>
    'patch_$patchNumber.$locale.json';

/// One Patch's complete structured change notes.
class PatchDetail {
  const PatchDetail({
    required this.schemaVersion,
    required this.locale,
    required this.patchNumber,
    required this.patchName,
    required this.timestamp,
    required this.sections,
  });

  factory PatchDetail.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != patchDetailSchemaVersion) {
      throw FormatException(
        'Unsupported patch-detail schema_version $schemaVersion '
        '(app expects $patchDetailSchemaVersion)',
      );
    }
    final rawSections = json['sections'];
    if (rawSections is! List) {
      throw const FormatException(
        'Patch detail: "sections" missing or not a list',
      );
    }
    return PatchDetail(
      schemaVersion: schemaVersion,
      locale: _requiredString(json, 'locale'),
      patchNumber: _requiredString(json, 'patch_number'),
      patchName: _requiredString(json, 'patch_name'),
      timestamp: _requiredInt(json, 'timestamp'),
      sections: rawSections
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw FormatException('Section entry is not an object: $raw');
            }
            return PatchSection.fromJson(raw);
          })
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String locale;
  final String patchNumber;
  final String patchName;
  final int timestamp;
  final List<PatchSection> sections;

  DateTime get releaseDate =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'locale': locale,
    'patch_number': patchNumber,
    'patch_name': patchName,
    'timestamp': timestamp,
    'sections': sections.map((s) => s.toJson()).toList(growable: false),
  };
}

/// One major section of changes (e.g. "General", "Items", "Heroes").
class PatchSection {
  const PatchSection({required this.title, required this.groups});

  factory PatchSection.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['groups'];
    if (rawGroups is! List) {
      throw const FormatException(
        'PatchSection: "groups" missing or not a list',
      );
    }
    return PatchSection(
      title: _requiredString(json, 'title'),
      groups: rawGroups
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw FormatException('Group entry is not an object: $raw');
            }
            return PatchChangeGroup.fromJson(raw);
          })
          .toList(growable: false),
    );
  }

  final String title;
  final List<PatchChangeGroup> groups;

  Map<String, Object?> toJson() => {
    'title': title,
    'groups': groups.map((g) => g.toJson()).toList(growable: false),
  };
}

/// One entity or topic within a section (e.g. "Anti-Mage", "Blink Dagger").
class PatchChangeGroup {
  const PatchChangeGroup({
    required this.title,
    this.heroId,
    this.itemId,
    this.iconUrl,
    required this.lines,
  });

  factory PatchChangeGroup.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    if (rawLines is! List) {
      throw const FormatException(
        'PatchChangeGroup: "lines" missing or not a list',
      );
    }
    return PatchChangeGroup(
      title: _requiredString(json, 'title'),
      heroId: json['hero_id'] is num ? (json['hero_id'] as num).toInt() : null,
      itemId: json['item_id'] is num ? (json['item_id'] as num).toInt() : null,
      iconUrl: json['icon_url'] as String?,
      lines: rawLines
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw FormatException('Line entry is not an object: $raw');
            }
            return PatchChangeLine.fromJson(raw);
          })
          .toList(growable: false),
    );
  }

  final String title;
  final int? heroId;
  final int? itemId;
  final String? iconUrl;
  final List<PatchChangeLine> lines;

  Map<String, Object?> toJson() => {
    'title': title,
    if (heroId != null) 'hero_id': heroId,
    if (itemId != null) 'item_id': itemId,
    if (iconUrl != null) 'icon_url': iconUrl,
    'lines': lines.map((l) => l.toJson()).toList(growable: false),
  };
}

/// One indented change line.
class PatchChangeLine {
  const PatchChangeLine({required this.text, this.indentLevel = 1, this.badge});

  factory PatchChangeLine.fromJson(Map<String, dynamic> json) {
    return PatchChangeLine(
      text: _requiredString(json, 'text'),
      indentLevel: json['indent_level'] is num
          ? (json['indent_level'] as num).toInt()
          : 1,
      badge: json['badge'] as String?,
    );
  }

  final String text;
  final int indentLevel;
  final String? badge;

  Map<String, Object?> toJson() => {
    'text': text,
    'indent_level': indentLevel,
    if (badge != null) 'badge': badge,
  };
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Patch detail: "$key" missing or not an int: $value');
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('Patch detail: "$key" missing or not a string: $value');
}
