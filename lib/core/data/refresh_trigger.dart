// Refresh trigger (spec: "refresh triggers on cold start/foreground").
//
// A tiny observer widget that runs one refresh cycle when the app launches
// (cold start) and every time it returns to the foreground. The refresher
// itself enforces the 24h TTL and the silent-failure posture, so this widget
// stays policy-free: trigger, await, bump the epoch on success. Failures are
// invisible here by construction — nothing to show, nothing to crash.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'refresh_epoch.dart';
import 'snapshot_refresher.dart';

/// Wraps the app: fires [SnapshotRefresher.refresh] on cold start and on
/// every resume, then bumps [refreshEpochProvider] when data changed so
/// the UI re-reads through the override-first sources.
class RefreshTrigger extends ConsumerStatefulWidget {
  const RefreshTrigger({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RefreshTrigger> createState() => _RefreshTriggerState();
}

class _RefreshTriggerState extends ConsumerState<RefreshTrigger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh(); // cold start
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final committed = await ref.read(snapshotRefresherProvider).refresh();
    // `mounted` guard: an unmount during the await makes the epoch bump
    // pointless (nobody is watching), and Riverpod forbids ref use after
    // disposal.
    if (committed && mounted) {
      ref.read(refreshEpochProvider.notifier).bump();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
