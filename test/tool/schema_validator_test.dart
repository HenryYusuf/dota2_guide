// Tests for snapshot tool schema validation and shape diffing.
//
// Ensures Valve-side or converter schema drift is caught with clear reports
// before publishing snapshots (User Story 42 & Issue 11).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dota2_guide/core/data/datafeed_client.dart';

import '../../tool/schema_validator.dart';
import '../core/data/fake_datafeed_client.dart';
import '../features/heroes/synthetic_herodata_feed.dart';

void main() {
  group('diffSchemaShape', () {
    test('identical structures produce no drift', () {
      final committed = {
        'schema_version': 1,
        'locale': 'english',
        'hero': {
          'id': 1,
          'name': 'Anti-Mage',
          'stats': {'armor': 6.16, 'active': true},
        },
        'tags': ['carry', 'escape'],
      };
      final candidate = {
        'schema_version': 1,
        'locale': 'english',
        'hero': {
          'id': 2,
          'name': 'Axe',
          'stats': {'armor': 3.5, 'active': false},
        },
        'tags': ['initiator', 'durable'],
      };

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, isEmpty);
    });

    test('detects type mismatch', () {
      final committed = {'id': 1, 'name': 'Anti-Mage'};
      final candidate = {'id': 'one', 'name': 'Anti-Mage'};

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, hasLength(1));
      expect(drifts.first.path, r'$.id');
      expect(drifts.first.message, contains('type mismatch'));
    });

    test('detects missing key in candidate', () {
      final committed = {'id': 1, 'name': 'Anti-Mage'};
      final candidate = {'id': 1};

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, hasLength(1));
      expect(drifts.first.path, r'$.name');
      expect(drifts.first.message, contains('missing key'));
    });

    test('detects unexpected extra key in candidate', () {
      final committed = {'id': 1, 'name': 'Anti-Mage'};
      final candidate = {'id': 1, 'name': 'Anti-Mage', 'extra_field': 'drift'};

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, hasLength(1));
      expect(drifts.first.path, r'$.extra_field');
      expect(drifts.first.message, contains('unexpected field'));
    });

    test('detects drift inside list elements', () {
      final committed = {
        'heroes': [
          {'id': 1, 'name': 'Anti-Mage'},
        ],
      };
      final candidate = {
        'heroes': [
          {'id': 1, 'name': 'Anti-Mage'},
          {'id': '2', 'name': 'Axe'},
        ],
      };

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, hasLength(1));
      expect(drifts.first.path, r'$.heroes[1].id');
      expect(drifts.first.message, contains('type mismatch'));
    });

    test('detects drift when candidate is string but committed is int', () {
      final committed = {'id': 1};
      final candidate = {'id': '1'};

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, hasLength(1));
      expect(drifts.first.path, r'$.id');
      expect(drifts.first.message, contains('type mismatch'));
    });

    test('detects drift when candidate list is empty but committed is not', () {
      final committed = {
        'heroes': [
          {'id': 1},
        ],
      };
      final candidate = {'heroes': []};

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, hasLength(1));
      expect(drifts.first.path, r'$.heroes');
      expect(drifts.first.message, contains('empty'));
    });

    test('allows null where committed schema is null', () {
      final committed = {'id': 1, 'shard_text': null};
      final candidate = {'id': 1, 'shard_text': null};

      final drifts = diffSchemaShape(candidate, committed);
      expect(drifts, isEmpty);
    });
  });

  group('validateSnapshot', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('schema_val_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'validates successfully against feeds matching committed snapshot',
      () async {
        // Create minimal committed snapshot in tempDir
        final heroesFile = File('${tempDir.path}/heroes.english.json');
        heroesFile.writeAsStringSync(
          jsonEncode({
            'schema_version': 1,
            'locale': 'english',
            'heroes': [
              {
                'id': 1,
                'valve_key': 'npc_dota_hero_antimage',
                'localized_name': 'Anti-Mage',
                'primary_attribute': 'agility',
                'complexity': 1,
                'portrait_url': 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/antimage.png',
              },
            ],
          }),
        );

        final heroDetailFile = File('${tempDir.path}/hero_1.english.json');
        final committedDetail = jsonDecode(
          File('assets/data/hero_1.english.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        heroDetailFile.writeAsStringSync(jsonEncode(committedDetail));

        final feed = FakeDatafeedClient();
        feed.documents['$datafeedBaseUrl/herolist?language=english'] = {
          'result': {
            'status': 1,
            'data': {
              'heroes': [
                {
                  'id': 1,
                  'name': 'npc_dota_hero_antimage',
                  'name_loc': 'Anti-Mage',
                  'primary_attr': 1,
                  'complexity': 1,
                },
              ],
            },
          },
        };

        feed.documents[heroDataFeedUrl(1, locale: 'english')] = feedDocument(
          heroFeed(),
        );

        final report = await validateSnapshot(
          feed: feed,
          snapshotDir: tempDir.path,
          locale: 'english',
          heroesOnly: true,
          sampleHeroDetails: 1,
        );

        expect(report.hasDrift, isFalse);
        expect(report.driftsByFile, isEmpty);
        expect(report.errors, isEmpty);
        expect(report.validatedFilesCount, greaterThanOrEqualTo(2));
        expect(report.formatReport(), contains('SCHEMA VALIDATION PASSED'));
      },
    );

    test(
      'flags error when feed converter throws FormatException (feed drift)',
      () async {
        final feed = FakeDatafeedClient();
        // Malformed feed missing 'result'
        feed.documents['$datafeedBaseUrl/herolist?language=english'] = {
          'invalid_payload': true,
        };

        final report = await validateSnapshot(
          feed: feed,
          snapshotDir: tempDir.path,
          locale: 'english',
          heroesOnly: true,
        );

        expect(report.hasDrift, isTrue);
        expect(report.errors, isNotEmpty);
        expect(report.formatReport(), contains('SCHEMA DRIFT DETECTED'));
      },
    );

    test(
      'flags drift when candidate schema shape diverges from committed',
      () async {
        // Committed snapshot expects localized_name
        final heroesFile = File('${tempDir.path}/heroes.english.json');
        heroesFile.writeAsStringSync(
          jsonEncode({
            'schema_version': 1,
            'locale': 'english',
            'heroes': [
              {
                'id': 1,
                'valve_key': 'npc_dota_hero_antimage',
                'localized_name': 'Anti-Mage',
                'primary_attribute': 'agility',
                'complexity': 1,
                'portrait_url': 'https://example.com/portrait.png',
                'old_field_that_drifted': 'legacy',
              },
            ],
          }),
        );

        final feed = FakeDatafeedClient();
        feed.documents['$datafeedBaseUrl/herolist?language=english'] = {
          'result': {
            'status': 1,
            'data': {
              'heroes': [
                {
                  'id': 1,
                  'name': 'npc_dota_hero_antimage',
                  'name_loc': 'Anti-Mage',
                  'primary_attr': 1,
                  'complexity': 1,
                },
              ],
            },
          },
        };

        final report = await validateSnapshot(
          feed: feed,
          snapshotDir: tempDir.path,
          locale: 'english',
          heroesOnly: true,
          sampleHeroDetails: 0,
        );

        expect(report.hasDrift, isTrue);
        expect(report.driftsByFile, contains('heroes.english.json'));
        expect(
          report.driftsByFile['heroes.english.json']!.first.message,
          contains('missing key "old_field_that_drifted"'),
        );
      },
    );

    test('flags error when committed snapshot file is missing', () async {
      final feed = FakeDatafeedClient();
      feed.documents['$datafeedBaseUrl/herolist?language=english'] = {
        'result': {
          'status': 1,
          'data': {'heroes': []},
        },
      };

      // tempDir has no files
      final report = await validateSnapshot(
        feed: feed,
        snapshotDir: tempDir.path,
        locale: 'english',
        heroesOnly: true,
      );

      expect(report.hasDrift, isTrue);
      expect(report.errors, isNotEmpty);
      expect(
        report.errors.first,
        contains('Missing committed snapshot file: heroes.english.json'),
      );
    });
  });
}
