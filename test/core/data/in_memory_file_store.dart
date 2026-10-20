// In-memory FileStore for repository/refresh tests: no dart:io, no platform
// channels (spec: repository tests drive the refresh with a fake file store).
//
// Shared by the override-store, refresher, and refresh-E2E tests.

import 'package:dota2_guide/core/data/file_store.dart';

class InMemoryFileStore implements FileStore {
  /// Path → content. Exposed for assertions about what was written where.
  final Map<String, String> files = {};

  /// When set, writes to a path containing this marker throw — simulates a
  /// full disk mid-commit so tests can prove a failed refresh keeps the
  /// previous data intact.
  String? failWritesContaining;

  @override
  Future<String?> readOrNull(String path) async => files[path];

  @override
  Future<void> write(String path, String contents) async {
    _throwIfDoomed(path);
    files[path] = contents;
  }

  @override
  Future<void> writeAtomic(String path, String contents) async {
    _throwIfDoomed(path);
    files[path] = contents;
  }

  @override
  Future<List<String>> listDirs(String dir) async => files.keys
      .where((path) => path.startsWith('$dir/'))
      .map((path) => path.substring(dir.length + 1).split('/').first)
      .toSet()
      .where((name) => files.keys.any((p) => p.startsWith('$dir/$name/')))
      .toList();

  @override
  Future<void> deleteDir(String dir) async {
    files.removeWhere((path, _) => path.startsWith('$dir/'));
  }

  void _throwIfDoomed(String path) {
    final failWith = failWritesContaining;
    if (failWith != null && path.contains(failWith)) {
      throw Exception('Simulated write failure: $path');
    }
  }
}
