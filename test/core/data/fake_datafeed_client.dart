// Fake DatafeedClient for refresher/E2E tests: canned versions and feed
// documents, call counters, and switches for simulating a dead feed. No
// HTTP, no platform channels.

import 'package:dota2_guide/core/data/datafeed_client.dart';

class FakeDatafeedClient implements DatafeedClient {
  /// The version the probe reports; null simulates a feed with no meta block
  /// (observed live 2026-10-21).
  int? version;

  /// Feed URL → decoded document served by [fetchJson].
  final Map<String, Map<String, dynamic>> documents = {};

  bool failProbe = false;
  bool failFetch = false;

  int probeCalls = 0;
  int fetchCalls = 0;

  @override
  Future<int?> probeDataVersion() async {
    probeCalls++;
    if (failProbe) throw Exception('Simulated: feed unreachable');
    return version;
  }

  @override
  Future<Map<String, dynamic>> fetchJson(String url) async {
    fetchCalls++;
    if (failFetch) throw Exception('Simulated: feed unreachable');
    final document = documents[url];
    if (document == null) {
      throw Exception('Simulated: no canned document for $url');
    }
    return document;
  }
}
