/// URL conventions for Valve's Steam CDN.
///
/// Pure Dart (no Flutter imports) so the snapshot tool in `tool/` can share
/// it with the app: the CDN path conventions are a single source of truth.
///
/// The paths follow the ones Valve's own `dota2.com` front-end uses; they were
/// verified live on 2026-10-20 — see `docs/research/dota2-data-sources.md`
/// §3.1. Media is always streamed at runtime and never bundled (ADR-0001).
abstract final class CdnUrls {
  /// Canonical CDN host (all Valve edge hosts serve the same bytes).
  static const host = 'https://cdn.steamstatic.com';

  /// Directory holding hero portraits, named by [heroPortrait]'s key.
  static const _heroPortraits = '$host/apps/dota2/images/dota_react/heroes';

  /// Portrait for the hero with the given Valve key (e.g. `antimage` for
  /// `npc_dota_hero_antimage`) — a 256×144 PNG.
  ///
  /// The key must be the Valve key, never the display name: `windranger.png`
  /// 404s while `windrunner.png` serves (verified 2026-10-20).
  static String heroPortrait(String valveHeroKey) =>
      '$_heroPortraits/$valveHeroKey.png';

  /// Directory holding ability icons, named by the FULL ability name
  /// (e.g. `antimage_blink`) — a flat convention, not namespaced per hero.
  static const _abilityIcons = '$host/apps/dota2/images/dota_react/abilities';

  /// Icon for the ability with the given full ability name — a 128×128 PNG.
  static String abilityIcon(String abilityName) =>
      '$_abilityIcons/$abilityName.png';

  /// Strips the `npc_dota_hero_` prefix from a Valve hero name, returning the
  /// CDN key (`npc_dota_hero_antimage` → `antimage`).
  static String heroKeyFromValveName(String valveHeroName) =>
      valveHeroName.replaceFirst('npc_dota_hero_', '');
}
