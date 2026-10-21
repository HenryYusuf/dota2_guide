import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data/file_store.dart';
import '../../core/data/snapshot_refresher.dart';
import 'news_repository.dart';

final newsRepositoryProvider = Provider<NewsRepository>(
  (ref) => LiveNewsRepository(
    fileStore: ref.watch(fileStoreProvider),
    feedClient: ref.watch(datafeedClientProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The Valve news list. Retry is user-driven (Home's inline Retry invalidates
/// this), so Riverpod's automatic backoff retry is disabled.
final newsProvider = FutureProvider<List<NewsItem>>(
  (ref) => ref.watch(newsRepositoryProvider).loadNews(),
  retry: (_, _) => null,
);

/// Opens a URL in the external browser. Overridden in widget tests.
final externalUrlLauncherProvider = Provider<Future<void> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
