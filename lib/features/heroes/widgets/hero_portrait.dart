import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One Hero portrait, streamed from the Valve CDN at runtime.
///
/// Portraits are never bundled (ADR-0001), so this is the Heroes grid's only
/// networked widget: offline it degrades to a neutral silhouette instead of
/// an error. The detail page reuses it for header media and Ability icons
/// (same URL shape, same fallback posture) via [semanticsNoun].
class HeroPortrait extends StatelessWidget {
  const HeroPortrait({
    super.key,
    required this.url,
    required this.heroName,
    this.semanticsNoun = 'portrait',
  });

  /// Absolute CDN URL from the hero index ([HeroSummary.portraitUrl]).
  final String url;

  /// Used as the screen-reader label, so the portrait is not an unlabelled
  /// image next to the name.
  final String heroName;

  /// What the image IS — "portrait" for grid tiles, "ability icon" on the
  /// detail page.
  final String semanticsNoun;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$heroName $semanticsNoun',
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _PortraitFallback(),
        errorWidget: (context, url, error) => const _PortraitFallback(),
      ),
    );
  }
}

/// Neutral silhouette shown until the portrait arrives or when it cannot
/// (no network, CDN miss) — calm, not an error state.
class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.surface,
      child: Center(child: Icon(Icons.person, size: 32, color: Colors.white24)),
    );
  }
}
