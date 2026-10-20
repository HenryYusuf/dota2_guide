// Valve datafeed access for refresh (ADR-0001: key-free official datafeeds
// only, never KV extraction). Two operations, both silent-failure friendly:
// the client THROWS on network/parse problems and the refresher decides
// what the user sees (nothing — stale data is preserved).
//
// Empirical notes (verified live 2026-10-21):
// - No feed currently serves `meta.data_version` in a stable envelope, but
//   when the meta block is present it carries the version; probing it is
//   the cheapest full-version check (herolist is ~16 KB).
// - `language=en` is rejected ({"result":{"status":8}}); full tokens only
//   (`english`, `schinese`, …).

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// The two feed operations the refresh path needs. Feature units receive
/// this to build their app-schema files; tests substitute a fake.
abstract interface class DatafeedClient {
  /// The feed's current `data_version`, or `null` when the feed serves no
  /// version block (the meta block comes and goes — a null version means
  /// "can never match, always refetch on probe").
  Future<int?> probeDataVersion();

  /// The decoded JSON document at [url] (a full datafeed URL).
  Future<Map<String, dynamic>> fetchJson(String url);
}

/// Base for every Valve datafeed URL.
const String datafeedBaseUrl = 'https://www.dota2.com/datafeed';

/// Valve's English herolist feed (~16 KB). The probe reads its meta block
/// for `data_version` (the cheapest version check available); the Heroes
/// refresh unit reads its data. One URL, two consumers.
const String heroListFeedUrl = '$datafeedBaseUrl/herolist?language=english';

/// Production client over `package:http`.
class HttpDatafeedClient implements DatafeedClient {
  HttpDatafeedClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<int?> probeDataVersion() async {
    final feed = await fetchJson(heroListFeedUrl);
    final meta = _section(feed, outerKey: 'result', innerKey: 'meta');
    final version = meta?['data_version'];
    if (version == null) return null;
    if (version is! int) {
      throw FormatException('Feed meta.data_version not an int: $version');
    }
    return version;
  }

  @override
  Future<Map<String, dynamic>> fetchJson(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode} from $url');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Feed response is not a JSON object');
    }
    return decoded;
  }

  Map<String, dynamic>? _section(
    Map<String, dynamic> json, {
    required String outerKey,
    required String innerKey,
  }) {
    final outer = json[outerKey];
    if (outer is! Map<String, dynamic>) return null;
    final inner = outer[innerKey];
    return inner is Map<String, dynamic> ? inner : null;
  }
}

/// How the app reaches Valve's datafeeds. Overridden in tests with a fake.
final datafeedClientProvider = Provider<DatafeedClient>(
  (ref) => HttpDatafeedClient(),
);
