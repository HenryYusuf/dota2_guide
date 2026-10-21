import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One Item icon, streamed from the Valve CDN at runtime.
///
/// Icons are never bundled (ADR-0001), so this is the Items tab's only
/// networked widget: offline it degrades to a neutral tile instead of an
/// error (same posture as the heroes' `HeroPortrait`).
class ItemIcon extends StatelessWidget {
  const ItemIcon({
    super.key,
    required this.url,
    required this.itemName,
    this.semanticsNoun = 'item icon',
  });

  /// Absolute CDN URL from the index ([ItemSummary.iconUrl]).
  final String url;

  /// Used as the screen-reader label, so the icon is not an unlabelled image
  /// next to the name.
  final String itemName;

  /// What the image IS — "item icon" everywhere in v1.
  final String semanticsNoun;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$itemName $semanticsNoun',
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _IconFallback(),
        errorWidget: (context, url, error) => const _IconFallback(),
      ),
    );
  }
}

/// Neutral tile shown until the icon arrives or when it cannot (no network,
/// CDN miss) — calm, not an error state.
class _IconFallback extends StatelessWidget {
  const _IconFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppTheme.surface,
      child: Center(
        child: Icon(Icons.category, size: 24, color: Colors.white24),
      ),
    );
  }
}
