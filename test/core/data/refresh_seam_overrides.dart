// The refresh seams every widget test that pumps the full app must stub:
// the cold-start RefreshTrigger reaches both the file store and the feed.
// Shared so the pair can't drift between test files.

import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/core/data/file_store.dart';
// Riverpod 3 keeps the Override type in misc, not the main library.
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_datafeed_client.dart';
import 'in_memory_file_store.dart';

/// In-memory storage plus a feed whose probe fails — the trigger's refresh
/// is then a silent no-op, which is exactly the first-launch offline
/// experience (and keeps every widget test off HTTP and dart:io).
List<Override> refreshSeamOverrides() => [
  fileStoreProvider.overrideWithValue(InMemoryFileStore()),
  datafeedClientProvider.overrideWithValue(
    FakeDatafeedClient()..failProbe = true,
  ),
];
