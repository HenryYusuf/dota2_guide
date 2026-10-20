// FileStore contract: the seam between core data code and dart:io (spec:
// repository tests drive refresh with a fake file store — the in-memory
// fake lives in `in_memory_file_store.dart`; this file pins the REAL
// implementation's behavior against a temp dir).

import 'dart:io';

import 'package:dota2_guide/core/data/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late DirectoryFileStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('aegis_file_store_test');
    store = DirectoryFileStore(rootPath: tempDir.path);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('readOrNull returns null for a path that does not exist', () async {
    expect(await store.readOrNull('nope.json'), isNull);
  });

  test('write then readOrNull round-trips content', () async {
    await store.write('gen1/heroes.english.json', '{"a":1}');

    expect(await store.readOrNull('gen1/heroes.english.json'), '{"a":1}');
  });

  test('write creates missing parent directories', () async {
    await store.write('gen/deep/nested/file.json', 'x');

    expect(await store.readOrNull('gen/deep/nested/file.json'), 'x');
  });

  test('writeAtomic replaces an existing file', () async {
    await store.write('manifest.json', 'old');
    await store.writeAtomic('manifest.json', 'new');

    expect(await store.readOrNull('manifest.json'), 'new');
  });

  test('writeAtomic leaves no temp file behind', () async {
    await store.writeAtomic('manifest.json', 'new');

    expect(await store.readOrNull('manifest.json.tmp'), isNull);
    final entries = tempDir.listSync().map((e) => e.uri.pathSegments.last);
    expect(entries, ['manifest.json']);
  });

  test('listDirs returns immediate subdirectory names only', () async {
    await store.write('gen/1/a.json', 'x');
    await store.write('gen/1/deep/b.json', 'x');
    await store.write('gen/2/a.json', 'x');
    await store.write('root.json', 'x');

    final dirs = await store.listDirs('gen');

    expect(dirs, unorderedEquals(['1', '2']));
  });

  test('deleteDir removes the directory and is a no-op when absent', () async {
    await store.write('gen/1/a.json', 'x');

    await store.deleteDir('gen/1');
    await store.deleteDir('never-existed');

    expect(await store.readOrNull('gen/1/a.json'), isNull);
    expect(await store.readOrNull('root.json'), isNull);
  });
}
