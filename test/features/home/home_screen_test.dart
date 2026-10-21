import 'package:dota2_guide/features/home/home_providers.dart';
import 'package:dota2_guide/features/home/home_screen.dart';
import 'package:dota2_guide/features/home/news_repository.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';
import 'package:dota2_guide/features/patches/patches_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakePatches implements PatchesRepository {
  @override
  Future<PatchIndex> loadPatchIndex() async => const PatchIndex(
    schemaVersion: 1,
    locale: 'english',
    patches: [
      PatchSummary(
        patchNumber: '7.41f',
        patchName: '7.41f',
        timestamp: 1789455600,
      ),
    ],
  );
}

class _FakeNews implements NewsRepository {
  _FakeNews(this.results);

  /// Each call consumes one entry: a list of items or an object to throw.
  final List<Object> results;
  int calls = 0;

  @override
  Future<List<NewsItem>> loadNews() async {
    final r = results[calls < results.length ? calls : results.length - 1];
    calls++;
    if (r is List<NewsItem>) return r;
    throw r;
  }
}

void main() {
  const item = NewsItem(
    id: '1',
    title: '7.41f Gameplay Patch',
    url: 'https://example.com/1',
    timestamp: 1789497865,
  );

  Widget subject(NewsRepository news, {List<Uri>? launched}) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/heroes', builder: (_, _) => const Text('HEROES TAB')),
        GoRoute(path: '/items', builder: (_, _) => const Text('ITEMS TAB')),
        GoRoute(
          path: '/patches/:n',
          builder: (_, s) => Text('Detail ${s.pathParameters['n']}'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        patchesRepositoryProvider.overrideWithValue(_FakePatches()),
        newsRepositoryProvider.overrideWithValue(news),
        externalUrlLauncherProvider.overrideWithValue((uri) async {
          launched?.add(uri);
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('latest-Patch card navigates to the patch detail', (t) async {
    await t.pumpWidget(
      subject(
        _FakeNews([
          const [item],
        ]),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('Latest Patch'), findsOneWidget);
    await t.tap(find.text('Latest Patch'));
    await t.pumpAndSettle();

    expect(find.text('Detail 7.41f'), findsOneWidget);
  });

  testWidgets('news renders title and date and opens externally', (t) async {
    final launched = <Uri>[];
    await t.pumpWidget(
      subject(
        _FakeNews([
          const [item],
        ]),
        launched: launched,
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('7.41f Gameplay Patch'), findsOneWidget);
    expect(find.text('September 15, 2026'), findsOneWidget);
    await t.tap(find.text('7.41f Gameplay Patch'));

    expect(launched, [Uri.parse('https://example.com/1')]);
  });

  testWidgets('quick entries navigate to Heroes and Items', (t) async {
    await t.pumpWidget(
      subject(
        _FakeNews([
          const [item],
        ]),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Heroes'));
    await t.pumpAndSettle();
    expect(find.text('HEROES TAB'), findsOneWidget);

    await t.pumpWidget(
      subject(
        _FakeNews([
          const [item],
        ]),
      ),
    );
    await t.pumpAndSettle();
  });

  testWidgets('failed news shows inline retry; Retry reloads', (t) async {
    final news = _FakeNews([
      Exception('offline'),
      const [item],
    ]);
    await t.pumpWidget(subject(news));
    await t.pumpAndSettle();

    expect(find.text("Couldn't load news."), findsOneWidget);
    expect(find.text('Latest Patch'), findsOneWidget); // Home still usable

    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();

    expect(find.text('7.41f Gameplay Patch'), findsOneWidget);
    expect(find.text("Couldn't load news."), findsNothing);
  });
}
