/// Refresh epoch: bumped after every successful snapshot commit so cached
/// feature providers re-read through the override-first source.
///
/// Without this, a completed refresh would be invisible until app restart —
/// the repository contract alone can't push new data into an already-resolved
/// FutureProvider. One int keeps the coupling minimal: features watch it,
/// the refresher bumps it, nobody shares types beyond that.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class RefreshEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Signals "committed data changed" — watched providers re-run.
  void bump() => state++;
}

/// Watched by providers that serve committed snapshot data.
final refreshEpochProvider = NotifierProvider<RefreshEpochNotifier, int>(
  RefreshEpochNotifier.new,
);
