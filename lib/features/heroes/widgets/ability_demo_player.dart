// The Ability demo-video player: plays one cached WebM inline on the detail
// card. Media streams at runtime and is never bundled (ADR-0001); the card
// builds this widget through [abilityDemoVideoBuilderProvider], so widget
// tests never touch the `video_player` platform (same seam posture as the
// portrait/icon builders).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Plays the Ability's cached demo video inline: muted, looping, tap to
/// pause/resume — the official site's card demos autoplay quietly, and a
/// card that starts shouting is a card users close.
class AbilityDemoPlayer extends StatefulWidget {
  const AbilityDemoPlayer({
    super.key,
    required this.video,
    required this.abilityName,
  });

  /// The cached local WebM (from `AbilityVideoRepository.videoFileFor`).
  final File video;

  /// Valve's full ability name — used for stable test keys only.
  final String abilityName;

  @override
  State<AbilityDemoPlayer> createState() => _AbilityDemoPlayerState();
}

class _AbilityDemoPlayerState extends State<AbilityDemoPlayer> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.video)
      ..setLooping(true)
      ..setVolume(0);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } on Exception {
      // A corrupt or unsupported cached file degrades exactly like a
      // missing one — never an error screen. Delete it (best-effort) so
      // the next play re-downloads a fresh copy instead of degrading
      // forever on a poisoned cache entry.
      try {
        await widget.video.delete();
      } on FileSystemException {
        // Nothing we can do; the next eviction pass reclaims it.
      }
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    setState(() {});
    unawaited(_controller.play());
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return DemoUnavailable(
        key: ValueKey<String>('ability-demo-corrupt-${widget.abilityName}'),
      );
    }
    final aspectRatio = _controller.value.aspectRatio;
    if (!_controller.value.isInitialized || aspectRatio == 0) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_controller.value.isPlaying) {
              unawaited(_controller.pause());
            } else {
              unawaited(_controller.play());
            }
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_controller),
            if (!_controller.value.isPlaying)
              const Center(
                child: Icon(Icons.play_arrow, size: 40, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

/// The small inline degraded state for an Ability whose demo is missing or
/// failed to download: a quiet note, never an error, so the description and
/// stats around it stay the point of the card. Callers attach a key to find
/// it in tests.
class DemoUnavailable extends StatelessWidget {
  const DemoUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            size: 16,
            color: Colors.white38,
          ),
          const SizedBox(width: 6),
          Text(
            'No demo video',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
