import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/features/patches/patch_feed_to_index.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';

void main() {
  group('patchIndexFromFeed', () {
    test(
      'converts feed JSON to app-schema patch index sorted latest-first',
      () {
        final feed = {
          'patches': [
            {
              'patch_number': '7.08',
              'patch_name': '7.08',
              'patch_timestamp': 1517472000,
            },
            {
              'patch_number': '7.41f',
              'patch_name': '7.41f',
              'patch_timestamp': 1789455600,
            },
          ],
          'success': true,
        };

        final json = patchIndexFromFeed(feed, locale: 'english');

        expect(json['schema_version'], patchIndexSchemaVersion);
        expect(json['locale'], 'english');

        final patches = json['patches']! as List<Object?>;
        expect(patches.length, 2);

        // Latest first
        final latest = patches.first as Map<String, Object?>;
        expect(latest['patch_number'], '7.41f');
        expect(latest['patch_name'], '7.41f');
        expect(latest['timestamp'], 1789455600);

        final older = patches.last as Map<String, Object?>;
        expect(older['patch_number'], '7.08');
        expect(older['timestamp'], 1517472000);

        // Verify PatchIndex.fromJson parses this output
        final index = PatchIndex.fromJson(json);
        expect(index.schemaVersion, patchIndexSchemaVersion);
        expect(index.locale, 'english');
        expect(index.patches.length, 2);
        expect(index.latestPatch?.patchNumber, '7.41f');
        expect(
          index.patches.first.releaseDate,
          DateTime.utc(2026, 9, 15, 7),
        ); // 1789455600
      },
    );

    test('throws FormatException on malformed feed', () {
      expect(
        () => patchIndexFromFeed({'invalid': true}, locale: 'english'),
        throwsFormatException,
      );
    });
  });
}
