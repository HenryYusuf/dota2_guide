import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/refresh_epoch.dart';
import '../../core/data/snapshot_source.dart';
import 'hero_detail.dart';
import 'hero_detail_repository.dart';
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

/// Builds the widget that shows one Hero's full-bleed header media on the
/// detail page (the same CDN portrait, cover-fit, behind the collapsing
/// header).
typedef HeroHeaderBuilder = Widget Function(
  BuildContext context,
  HeroDetail detail,
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

/// Builds the widget that shows one Ability's icon on the detail page.
typedef AbilityIconBuilder = Widget Function(
  BuildContext context,
  AbilityDetail ability,
);

/// One Hero's detail page data, read through the override-first source —
/// same contract as the roster, one file per Hero.
final heroDetailRepositoryProvider = Provider<HeroDetailRepository>(
  (ref) => SnapshotHeroDetailRepository(ref.watch(snapshotSourceProvider)),
);

/// One Hero's detail, re-read after every successful refresh so a version
/// bump shows up on the detail page too, not just the grid.
final heroDetailProvider = FutureProvider.family<HeroDetail, int>((
  ref,
  heroId,
) {
  ref.watch(refreshEpochProvider);
  return ref.watch(heroDetailRepositoryProvider).loadHeroDetail(heroId);
});

/// Default portrait widget: streams from the CDN with a quiet fallback while
/// loading or when offline.
final portraitBuilderProvider = Provider<PortraitBuilder>(
  (ref) =>
      (context, hero) =>
          HeroPortrait(url: hero.portraitUrl, heroName: hero.localizedName),
);

/// Default header media: the Hero's CDN portrait, cover-fit with the crop
/// centred on the face area, quiet fallback when offline (same posture as
/// [portraitBuilderProvider]).
final heroHeaderBuilderProvider = Provider<HeroHeaderBuilder>(
  (ref) =>
      (context, detail) => HeroPortrait(
        url: detail.hero.portraitUrl,
        heroName: detail.hero.localizedName,
      ),
);

/// Default Ability icon: streams from the Valve CDN with the same quiet
/// fallback posture as the portraits.
final abilityIconBuilderProvider = Provider<AbilityIconBuilder>(
  (ref) =>
      (context, ability) => HeroPortrait(
        url: ability.iconUrl,
        heroName: ability.displayName,
        semanticsNoun: 'ability icon',
      ),
);
