// Fan-out helper for one-feed-request-per-item refreshes (the Heroes detail
// unit fetches one herodata document per Hero). Pure Dart: shared by
// `tool/snapshot.dart`, which cannot import anything reaching `dart:ui`.

/// Runs [task] over [items] with at most [concurrency] in flight, preserving
/// input order in the result.
Future<List<R>> mapConcurrently<T, R>(
  Iterable<T> items,
  int concurrency,
  Future<R> Function(T item) task,
) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= items.length) return;
      results[index] = await task(items.elementAt(index));
    }
  }

  await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
  return results.cast<R>();
}
