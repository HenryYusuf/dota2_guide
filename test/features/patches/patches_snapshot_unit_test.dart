import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dota2_guide/core/data/datafeed_client.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';
import 'package:dota2_guide/features/patches/patches_repository.dart';
import 'package:dota2_guide/features/patches/patches_snapshot_unit.dart';

import '../../core/data/fake_datafeed_client.dart';

void main() {
  late FakeDatafeedClient feed;

  setUp(() => feed = FakeDatafeedClient());

  test(
    'the patch index unit emits the index under the bundled unit name',
    () async {
      feed.documents['$datafeedBaseUrl/patchnoteslist?language=english'] = {
        'patches': [
          {
            'patch_number': '7.41f',
            'patch_name': '7.41f',
            'patch_timestamp': 1789455600,
          },
        ],
        'success': true,
      };

      final files = await patchesSnapshotUnit.fetch(feed);

      expect(files.keys, [patchIndexUnit]);
      final parsed = PatchIndex.fromJson(
        jsonDecode(files[patchIndexUnit]!) as Map<String, dynamic>,
      );
      expect(parsed.schemaVersion, patchIndexSchemaVersion);
      expect(parsed.locale, 'english');
      expect(parsed.patches.length, 1);
      expect(parsed.patches.first.patchNumber, '7.41f');
    },
  );
}
