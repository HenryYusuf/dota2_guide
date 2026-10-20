// Override-first reads (spec: "reads prefer override files, fall back to
// bundled assets"). Feature-generic: a feature names its override unit and
// the bundled asset to fall back to; core never parses feature schemas and
// features never touch storage.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_loader.dart';
import 'override_store.dart';

class SnapshotSource {
  SnapshotSource({required this.overrides, required this.assets});

  final OverrideStore overrides;
  final AssetLoader assets;

  /// The freshest available content for [unit]: the committed override when
  /// one exists, otherwise the bundled asset at [assetPath]. Offline-first
  /// by construction — the asset read is the unconditional fallback.
  Future<String> readUnit(String unit, String assetPath) async {
    final override = await overrides.readOrNull(unit);
    if (override != null) return override;
    return assets.readAsString(assetPath);
  }
}

/// How features reach override-preferred reads. Overridden in tests with a
/// [SnapshotSource] over fakes.
final snapshotSourceProvider = Provider<SnapshotSource>(
  (ref) => SnapshotSource(
    overrides: ref.watch(overrideStoreProvider),
    assets: ref.watch(assetLoaderProvider),
  ),
);
