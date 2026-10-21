// CDN URL conventions, pinned against the paths verified live on 2026-10-20
// and re-verified 2026-10-21 (docs/research/dota2-data-sources.md §3.1):
// ability demo videos are TWO levels — the hero folder, then the FULL
// ability name — unlike the flat ability-icon convention. The flat video
// form (`…/abilities/antimage_blink.webm`) 404s, so this test is the
// regression guard for a path shape the app cannot discover at runtime.

import 'package:dota2_guide/core/cdn/cdn_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('abilityDemoVideo is the two-level hero-folder/full-name path', () {
    // The exact URL that returned 200 / video/webm from the live CDN.
    expect(
      CdnUrls.abilityDemoVideo('antimage', 'antimage_blink'),
      'https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/'
      'antimage/antimage_blink.webm',
    );
  });

  test('abilityDemoVideo keeps the hero prefix in the file name', () {
    // Verified live: the file is the FULL ability name, not the short one —
    // `…/abilities/antimage/mana_void.webm` 404s.
    expect(
      CdnUrls.abilityDemoVideo('antimage', 'antimage_mana_void'),
      endsWith('/abilities/antimage/antimage_mana_void.webm'),
    );
  });

  test('heroKeyFromValveName feeds the video folder from a feed hero name', () {
    final heroKey = CdnUrls.heroKeyFromValveName('npc_dota_hero_antimage');

    expect(
      CdnUrls.abilityDemoVideo(heroKey, 'antimage_blink'),
      endsWith('/abilities/antimage/antimage_blink.webm'),
    );
  });
}
