import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reads bundled snapshot files.
///
/// The one seam between repositories and the asset bundle: repositories take
/// an [AssetLoader], so tests inject an in-memory fake and no test ever needs
/// a Flutter asset bundle (spec: repository tests drive reads with a fake
/// loader).
abstract interface class AssetLoader {
  /// Returns the content of the bundled file at [assetPath], or throws if the
  /// asset is missing (a build-time packaging error, never a network concern).
  Future<String> readAsString(String assetPath);
}

/// Production loader: Flutter's asset bundle.
class BundleAssetLoader implements AssetLoader {
  const BundleAssetLoader();

  @override
  Future<String> readAsString(String assetPath) =>
      rootBundle.loadString(assetPath);
}

/// How repositories reach bundled snapshot files. Overridden in tests.
final assetLoaderProvider = Provider<AssetLoader>(
  (ref) => const BundleAssetLoader(),
);
