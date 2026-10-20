import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_source.dart';
import 'hero_index.dart';
import 'heroes_repository.dart';
import 'widgets/hero_portrait.dart';

/// Builds the widget that shows one Hero's portrait.
///
/// Injected through a provider so widget tests can stand in for the Valve CDN
/// (media streams at runtime and is never bundled — ADR-0001; spec: widget
/// tests must not touch HTTP, assets, or CDN).
typedef PortraitBuilder = Widget Function(
  BuildContext context,
  HeroSummary hero,
);

/// The Hero roster contract the Heroes tab consumes (the spec's single test
/// seam: UI → repository provider, never UI → HTTP/files). Reads prefer a
/// committed refresh override and fall back to the bundled snapshot.
final heroesRepositoryProvider = Provider<HeroesRepository>(
  (ref) => SnapshotHeroesRepository(ref.watch(snapshotSourceProvider)),
);

/// The bundled roster, parsed once per app run — plus re-read after every
/// successful refresh (epoch bump), so a version bump shows up live.
final heroesProvider = FutureProvider<List<HeroSummary>>((ref) {
  ref.watch(refreshEpochProvider);
  return ref.watch(heroesRepositoryProvider).loadHeroes();
});

/// Default portrait widget: streams from the CDN with a quiet fallback while
/// loading or when offline.
final portraitBuilderProvider = Provider<PortraitBuilder>(
  (ref) =>
      (context, hero) =>
          HeroPortrait(url: hero.portraitUrl, heroName: hero.localizedName),
);
