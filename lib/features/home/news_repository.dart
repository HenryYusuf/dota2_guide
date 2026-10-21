import 'dart:convert';

import '../../core/data/datafeed_client.dart';
import '../../core/data/file_store.dart';

/// Valve's own announcements for Dota 2 (Steam appid 570), filtered to the
/// `steam_community_announcements` feed so third-party press is excluded
/// (ADR-0001: the one non-datafeed endpoint).
const String newsFeedUrl =
    'https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/'
    '?appid=570&count=20&maxlength=1&feeds=steam_community_announcements';

/// How long a fetched news list is served without touching the network.
const Duration newsCacheTtl = Duration(hours: 24);

/// File-store path of the cached news list.
const String newsCachePath = 'news/news.json';

/// One Valve announcement.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.url,
    required this.timestamp,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final url = json['url'];
    final date = json['date'];
    if (title is! String || url is! String || date is! num) {
      throw FormatException('Malformed news item: $json');
    }
    return NewsItem(
      id: '${json['gid'] ?? url}',
      title: title,
      url: url,
      timestamp: date.toInt(),
    );
  }

  final String id;
  final String title;
  final String url;

  /// Unix timestamp in seconds.
  final int timestamp;

  DateTime get date =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  Map<String, Object?> toJson() => {
    'gid': id,
    'title': title,
    'url': url,
    'date': timestamp,
  };
}

/// Contract consumed by Home for the Valve news list.
abstract interface class NewsRepository {
  /// The latest announcements, newest first. Throws when the list can be
  /// neither served from a usable cache nor fetched, so Home can show its
  /// small inline retry.
  Future<List<NewsItem>> loadNews();
}

/// Fetches the official news feed, caching the list on disk for 24 hours.
/// An expired cache is a fallback if the refetch fails (stale beats nothing).
class LiveNewsRepository implements NewsRepository {
  LiveNewsRepository({
    required this.fileStore,
    required this.feedClient,
    required this.clock,
  });

  final FileStore fileStore;
  final DatafeedClient feedClient;
  final DateTime Function() clock;

  @override
  Future<List<NewsItem>> loadNews() async {
    final cached = await _readCache();
    if (cached != null && clock().difference(cached.fetchedAt) < newsCacheTtl) {
      return cached.items;
    }
    try {
      final items = _parse(await feedClient.fetchJson(newsFeedUrl));
      await _writeCache(items);
      return items;
    } catch (_) {
      if (cached != null) return cached.items;
      rethrow;
    }
  }

  List<NewsItem> _parse(Map<String, dynamic> doc) {
    final raw = (doc['appnews'] as Map?)?['newsitems'];
    if (raw is! List) {
      throw const FormatException('News feed: "newsitems" missing');
    }
    return [
      for (final entry in raw)
        // Belt and braces: the URL already filters, but never show non-Valve
        // posts if the feed ever returns them.
        if (entry is Map<String, dynamic> &&
            entry['feedname'] == 'steam_community_announcements')
          NewsItem.fromJson(entry),
    ];
  }

  Future<void> _writeCache(List<NewsItem> items) async {
    try {
      await fileStore.writeAtomic(
        newsCachePath,
        jsonEncode({
          'fetched_at': clock().millisecondsSinceEpoch,
          'items': [for (final item in items) item.toJson()],
        }),
      );
    } catch (_) {
      // Cache failure must not fail a successful load.
    }
  }

  Future<({DateTime fetchedAt, List<NewsItem> items})?> _readCache() async {
    try {
      final raw = await fileStore.readOrNull(newsCachePath);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          json['fetched_at'] as int,
        ),
        items: [
          for (final e in json['items'] as List)
            NewsItem.fromJson(e as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      return null; // corrupt cache is treated as absent
    }
  }
}
