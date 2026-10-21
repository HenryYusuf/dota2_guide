import 'dart:convert';

import 'package:dota2_guide/features/home/news_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/data/fake_datafeed_client.dart';
import '../../core/data/in_memory_file_store.dart';

Map<String, dynamic> _feed() => {
  'appnews': {
    'newsitems': [
      {
        'gid': '1',
        'title': '7.41f Gameplay Patch',
        'url': 'https://example.com/1',
        'feedname': 'steam_community_announcements',
        'date': 1789497865,
      },
      {
        'gid': '2',
        'title': 'Third-party press',
        'url': 'https://example.com/2',
        'feedname': 'pcgamer',
        'date': 1789497000,
      },
    ],
  },
};

void main() {
  late FakeDatafeedClient feed;
  late InMemoryFileStore store;
  late DateTime now;

  LiveNewsRepository repo() =>
      LiveNewsRepository(fileStore: store, feedClient: feed, clock: () => now);

  setUp(() {
    feed = FakeDatafeedClient()..documents[newsFeedUrl] = _feed();
    store = InMemoryFileStore();
    now = DateTime(2026, 10, 21, 12);
  });

  test(
    'fetches from the Valve-announcements feed and keeps only Valve posts',
    () async {
      final items = await repo().loadNews();

      expect(newsFeedUrl, contains('feeds=steam_community_announcements'));
      expect(items.map((i) => i.title), ['7.41f Gameplay Patch']);
      expect(items.single.date.isUtc, isTrue);
    },
  );

  test('serves from cache within 24 h without refetching', () async {
    await repo().loadNews();
    now = now.add(const Duration(hours: 23));
    await repo().loadNews();

    expect(feed.fetchCalls, 1);
  });

  test('refetches once the cache is older than 24 h', () async {
    await repo().loadNews();
    now = now.add(const Duration(hours: 25));
    await repo().loadNews();

    expect(feed.fetchCalls, 2);
  });

  test('throws when the fetch fails and nothing is cached', () async {
    feed.failFetch = true;

    expect(repo().loadNews(), throwsException);
  });

  test('falls back to an expired cache when the refetch fails', () async {
    await repo().loadNews();
    now = now.add(const Duration(days: 3));
    feed.failFetch = true;

    final items = await repo().loadNews();

    expect(items, hasLength(1));
  });

  test('a corrupt cache is treated as absent', () async {
    store.files[newsCachePath] = jsonEncode({'oops': true});

    final items = await repo().loadNews();

    expect(items, hasLength(1));
    expect(feed.fetchCalls, 1);
  });
}
