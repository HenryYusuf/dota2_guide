import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/asset_loader.dart';
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
/// seam: UI → repository provider, never UI → HTTP/files).
final heroesRepositoryProvider = Provider<HeroesRepository>(
  (ref) => AssetHeroesRepository(ref.watch(assetLoaderProvider)),
);

/// The bundled roster, parsed once per app run. Always available offline;
/// issue 03 adds refresh overrides behind the same repository contract.
final heroesProvider = FutureProvider<List<HeroSummary>>(
  (ref) => ref.watch(heroesRepositoryProvider).loadHeroes(),
);

/// Default portrait widget: streams from the CDN with a quiet fallback while
/// loading or when offline.
final portraitBuilderProvider = Provider<PortraitBuilder>(
  (ref) =>
      (context, hero) =>
          HeroPortrait(url: hero.portraitUrl, heroName: hero.localizedName),
);
