import 'dart:convert';

import '../../core/data/snapshot_source.dart';
import 'patch_index.dart';

/// Bundled English patch index asset path.
const String patchIndexAssetPath = 'assets/data/patches.english.json';

/// The override-store unit for the patch index.
const String patchIndexUnit = 'patches.english.json';

/// Contract consumed by the Patches tab for listing patches.
abstract interface class PatchesRepository {
  Future<PatchIndex> loadPatchIndex();
}

/// Reads the patch index through [SnapshotSource]: a committed refresh override
/// wins, the bundled asset is the fallback.
class SnapshotPatchesRepository implements PatchesRepository {
  const SnapshotPatchesRepository(this._source);

  final SnapshotSource _source;

  @override
  Future<PatchIndex> loadPatchIndex() async {
    final raw = await _source.readUnit(patchIndexUnit, patchIndexAssetPath);
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Patch index file is not a JSON object');
    }
    return PatchIndex.fromJson(json);
  }
}
