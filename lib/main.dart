import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/data/file_store.dart';
import 'core/data/snapshot_refresher.dart';
import 'features/heroes/heroes_snapshot_unit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Platform-resolved once at startup (async), then handed to the sync
  // provider so everything downstream stays synchronously constructible.
  final appSupport = await getApplicationSupportDirectory();
  runApp(
    ProviderScope(
      overrides: [
        appSupportDirProvider.overrideWithValue(appSupport.path),
        // Feature refresh units; core never imports a feature, so the
        // composition happens here, at the root.
        snapshotUnitsProvider.overrideWithValue(const [
          heroesSnapshotUnit,
          heroDetailSnapshotUnit,
        ]),
      ],
      child: const AegisApp(),
    ),
  );
}
