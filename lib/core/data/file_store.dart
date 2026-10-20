// The file seam for refresh & override storage (spec: repository tests drive
// the refresh with a fake file store — `FileStore` is that contract; tests
// substitute an in-memory fake, production uses `DirectoryFileStore` under
// the app-support directory).
//
// Paths are relative to a store root and always use `/` separators; the real
// implementation joins them onto its root, so callers never touch dart:io.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal storage contract used by the snapshot/override code.
abstract interface class FileStore {
  /// Returns the contents at [path], or `null` when nothing is stored there
  /// (missing file is a normal state, not an error — stale-tolerant reads).
  Future<String?> readOrNull(String path);

  /// Writes [contents] to [path], creating parent directories as needed.
  Future<void> write(String path, String contents);

  /// Writes [contents] to [path] so readers see either the old file or the
  /// new one — never a partial write (atomic-from-the-user's-perspective
  /// commits: issue 03's manifest must land in one piece or not at all).
  Future<void> writeAtomic(String path, String contents);

  /// Names of the immediate subdirectories of [dir]; `[]` when [dir] does
  /// not exist. Used to locate and prune snapshot generations.
  Future<List<String>> listDirs(String dir);

  /// Recursively deletes [dir]; a no-op when it does not exist.
  Future<void> deleteDir(String dir);
}

/// [FileStore] backed by a real directory tree rooted at [rootPath].
class DirectoryFileStore implements FileStore {
  DirectoryFileStore({required this.rootPath});

  /// Absolute path every relative [FileStore] path is joined onto.
  final String rootPath;

  String _absolute(String path) => '$rootPath/$path';

  @override
  Future<String?> readOrNull(String path) async {
    final file = _file(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String path, String contents) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  @override
  Future<void> writeAtomic(String path, String contents) async {
    final file = _file(path);
    await file.parent.create(recursive: true);
    final temp = _file('$path.tmp');
    await temp.writeAsString(contents);
    await temp.rename(file.path);
  }

  @override
  Future<List<String>> listDirs(String dir) async {
    final directory = Directory(_absolute(dir));
    if (!await directory.exists()) return [];
    final names = <String>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is Directory) {
        names.add(entity.path.split(RegExp(r'[/\\]')).last);
      }
    }
    return names;
  }

  @override
  Future<void> deleteDir(String dir) async {
    final directory = Directory(_absolute(dir));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  File _file(String path) => File(_absolute(path));
}

/// Rooted where the OS keeps per-application support files — not the asset
/// bundle (read-only) and not temporary storage the system may reclaim.
final fileStoreProvider = Provider<FileStore>(
  (ref) => DirectoryFileStore(rootPath: ref.watch(appSupportDirProvider)),
);

/// Resolved once at startup (`path_provider` is async, so `main()` awaits it
/// and overrides this before `runApp`) — keeps every downstream provider
/// synchronously constructible. Tests override with a temp dir or swap
/// [fileStoreProvider] for the in-memory fake.
final appSupportDirProvider = Provider<String>(
  (ref) => throw UnimplementedError(
    'Overridden at startup with getApplicationSupportDirectory().path',
  ),
);
