// Repository seam: the Ability demo-video cache — first play downloads from
// the Valve CDN into a disk cache; every replay serves the cached file with
// no network at all (spec: "previously watched demo videos replayed from
// disk without re-downloading"); a CDN 404 (abilities without a demo are a
// real, expected state — the feed carries no video field) surfaces as
// [VideoUnavailableException]; the cache never grows past its cap, evicting
// least-recently-played first. Driven with a fake HTTP client and a real
// temp dir (same posture as file_store_test.dart pins the real FileStore).

import 'dart:io';

import 'package:dota2_guide/features/heroes/ability_video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory cacheDir;
  late List<Uri> requestedUrls;

  /// A fake CDN: serves [_served] bytes for any request, or 404s when the
  /// URL is not in it. Records every requested URL.
  MockClient cdn(Map<String, List<int>> served) => MockClient((request) async {
    requestedUrls.add(request.url);
    final bytes = served[request.url.toString()];
    if (bytes == null) {
      return http.Response('no demo at ${request.url}', 404);
    }
    return http.Response.bytes(bytes, 200);
  });

  /// A repository over [client]'s CDN, rooted at the temp cache dir. A new
  /// instance over the same dir = an app restart: the cache must survive it.
  AbilityVideoRepository repository(
    http.Client client, {
    int maxCacheBytes = abilityVideoCacheMaxBytes,
    DateTime Function()? clock,
  }) => CdnAbilityVideoRepository(
    client: client,
    cacheDir: cacheDir,
    maxCacheBytes: maxCacheBytes,
    clock: clock ?? DateTime.now,
  );

  final videoUrl =
      'https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/'
      'antimage/antimage_blink.webm';

  // The two other demos the cache tests fill the disk with — three 600 B
  // videos against a 1500 B cap.
  const urlB =
      'https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/'
      'axe/axe_berserkers_call.webm';
  const urlC =
      'https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/'
      'axe/axe_culling_blade.webm';
  Map<String, List<int>> threeDemos() => {
    videoUrl: List.filled(600, 1),
    urlB: List.filled(600, 2),
    urlC: List.filled(600, 3),
  };

  setUp(() {
    requestedUrls = [];
    cacheDir = Directory.systemTemp.createTempSync('aegis_video_cache_test');
  });

  tearDown(() => cacheDir.deleteSync(recursive: true));

  test('first play downloads the video into the disk cache', () async {
    final repo = repository(
      cdn({
        videoUrl: [1, 2, 3, 4],
      }),
    );

    final file = await repo.videoFileFor(videoUrl);

    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    expect(requestedUrls, [Uri.parse(videoUrl)]);
  });

  test(
    'a replay after restart serves the cached file with NO network',
    () async {
      // First play: download through a working CDN.
      final first = repository(
        cdn({
          videoUrl: [9, 9, 9],
        }),
      );
      final cached = await first.videoFileFor(videoUrl);

      // Restart: same cache dir, but a CDN that fails EVERY request — the
      // airplane-mode stand-in. Only a cache hit can succeed now.
      final offline = MockClient((request) async {
        throw const SocketException('airplane mode');
      });
      final replayed = await repository(offline).videoFileFor(videoUrl);

      expect(await replayed.readAsBytes(), [9, 9, 9]);
      expect(replayed.path, cached.path);
    },
  );

  test('distinct abilities cache to distinct files', () async {
    const other =
        'https://cdn.steamstatic.com/apps/dota2/videos/dota_react/abilities/'
        'antimage/antimage_mana_void.webm';
    final repo = repository(
      cdn({
        videoUrl: [1],
        other: [2],
      }),
    );

    final blink = await repo.videoFileFor(videoUrl);
    final manaVoid = await repo.videoFileFor(other);

    expect(await blink.readAsBytes(), [1]);
    expect(await manaVoid.readAsBytes(), [2]);
  });

  test('a missing demo (CDN 404) throws VideoUnavailableException', () async {
    final repo = repository(cdn(const {}));

    await expectLater(
      repo.videoFileFor(videoUrl),
      throwsA(isA<VideoUnavailableException>()),
    );
    // Nothing half-cached: a retry later downloads fresh.
    expect(cacheDir.listSync(recursive: true), isEmpty);
  });

  test('a server or network failure throws VideoDownloadException', () async {
    final failing = MockClient((request) async {
      throw const SocketException('no route to host');
    });

    await expectLater(
      repository(failing).videoFileFor(videoUrl),
      throwsA(isA<VideoDownloadException>()),
    );
    expect(cacheDir.listSync(recursive: true), isEmpty);
  });

  test('a non-200 CDN answer that is not 404 also fails as download', () async {
    final broken = MockClient((request) async => http.Response('oops', 500));

    await expectLater(
      repository(broken).videoFileFor(videoUrl),
      throwsA(isA<VideoDownloadException>()),
    );
  });

  test(
    'an unwritable cache degrades as a download failure, not a crash',
    () async {
      // A file where the cache directory should be: every write below it
      // throws FileSystemException (disk full / permissions stand-in). The
      // card must see a degradable failure, never a raw OS error.
      cacheDir.deleteSync(recursive: true);
      File(cacheDir.path).writeAsStringSync('not a directory');

      await expectLater(
        repository(
          cdn({
            videoUrl: [1, 2, 3],
          }),
        ).videoFileFor(videoUrl),
        throwsA(isA<VideoDownloadException>()),
      );
    },
  );

  test('the cache evicts least-recently-played files past the cap', () async {
    // Tiny cap: room for two of the three videos below.
    var now = DateTime.utc(2026, 10, 21, 8);
    final repo = repository(
      cdn(threeDemos()),
      maxCacheBytes: 1500,
      clock: () => now,
    );

    await repo.videoFileFor(videoUrl);
    now = now.add(const Duration(minutes: 1));
    await repo.videoFileFor(urlB);
    now = now.add(const Duration(minutes: 1));
    await repo.videoFileFor(urlC); // total 1800 > 1500 → A evicted

    final files = cacheDir
        .listSync(recursive: true)
        .whereType<File>()
        .map((file) => file.uri.pathSegments.join('/'))
        .toList();
    expect(
      files,
      hasLength(2),
      reason: 'cap 1500 B keeps only two 600 B files',
    );
    expect(
      files.any((path) => path.endsWith('antimage_blink.webm')),
      isFalse,
      reason: 'the least-recently-played video (A) is evicted first',
    );
    // Evicting A freed room: B and C replay from cache.
    final replayRepo = repository(
      MockClient((request) async => http.Response('', 500)),
      maxCacheBytes: 1500,
      clock: () => now,
    );
    expect((await replayRepo.videoFileFor(urlB)).lengthSync(), 600);
    expect((await replayRepo.videoFileFor(urlC)).lengthSync(), 600);
  });

  test(
    'replaying a video moves it to the front of the eviction order',
    () async {
      var now = DateTime.utc(2026, 10, 21, 8);
      final repo = repository(
        cdn(threeDemos()),
        maxCacheBytes: 1500,
        clock: () => now,
      );

      await repo.videoFileFor(videoUrl); // oldest…
      now = now.add(const Duration(minutes: 1));
      await repo.videoFileFor(urlB);
      now = now.add(const Duration(minutes: 1));
      await repo.videoFileFor(videoUrl); // …but replaying A makes B the oldest.
      now = now.add(const Duration(minutes: 1));
      await repo.videoFileFor(urlC); // 1800 > 1500 → B evicted, not A

      final fileA = File('${cacheDir.path}/antimage/antimage_blink.webm');
      expect(fileA.existsSync(), isTrue, reason: 'replayed A survives the cap');
      final fileB = File('${cacheDir.path}/axe/axe_berserkers_call.webm');
      expect(
        fileB.existsSync(),
        isFalse,
        reason: 'the replay moved A behind B, so B is evicted instead',
      );
    },
  );
}
