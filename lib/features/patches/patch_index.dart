/// Patch index: the app schema for the bundled Patch list snapshot.
///
/// The contract is the FILE, not this class: `dart run tool/snapshot.dart`
/// emits `assets/data/patches.<locale>.json` and
/// `test/features/patches/patch_index_test.dart` parses that real file to pin
/// the schema.
library;

/// Current schema version of the emitted patch-index file.
const int patchIndexSchemaVersion = 1;

/// Parsed content of one bundled patch-index file.
class PatchIndex {
  const PatchIndex({
    required this.schemaVersion,
    required this.locale,
    required this.patches,
  });

  factory PatchIndex.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schema_version');
    if (schemaVersion != patchIndexSchemaVersion) {
      throw FormatException(
        'Unsupported patch-index schema_version $schemaVersion '
        '(app expects $patchIndexSchemaVersion)',
      );
    }
    final rawPatches = json['patches'];
    if (rawPatches is! List) {
      throw const FormatException(
        'Patch index: "patches" missing or not a list',
      );
    }
    return PatchIndex(
      schemaVersion: schemaVersion,
      locale: _requiredString(json, 'locale'),
      patches: rawPatches
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw FormatException('Patch entry is not an object: $raw');
            }
            return PatchSummary.fromJson(raw);
          })
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String locale;
  final List<PatchSummary> patches;

  /// The newest patch in the index (first element).
  PatchSummary? get latestPatch => patches.firstOrNull;
}

/// One Patch summary item as the Patches tab list needs it.
class PatchSummary {
  const PatchSummary({
    required this.patchNumber,
    required this.patchName,
    required this.timestamp,
  });

  factory PatchSummary.fromJson(Map<String, dynamic> json) {
    return PatchSummary(
      patchNumber: _requiredString(json, 'patch_number'),
      patchName: _requiredString(json, 'patch_name'),
      timestamp: _requiredInt(json, 'timestamp'),
    );
  }

  /// Official patch number string, e.g. "7.41f".
  final String patchNumber;

  /// Display name of the patch, e.g. "7.41f".
  final String patchName;

  /// Unix timestamp in seconds.
  final int timestamp;

  /// UTC release date.
  DateTime get releaseDate =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  Map<String, Object?> toJson() => {
    'patch_number': patchNumber,
    'patch_name': patchName,
    'timestamp': timestamp,
  };
}

int _requiredInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Patch index: "$key" missing or not an int: $value');
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String) return value;
  throw FormatException('Patch index: "$key" missing or not a string: $value');
}
