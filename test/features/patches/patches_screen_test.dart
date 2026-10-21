import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dota2_guide/features/patches/patch_index.dart';
import 'package:dota2_guide/features/patches/patches_providers.dart';
import 'package:dota2_guide/features/patches/patches_repository.dart';
import 'package:dota2_guide/features/patches/patches_screen.dart';

class _FakePatchesRepository implements PatchesRepository {
  _FakePatchesRepository({this.index, this.error});

  final PatchIndex? index;
  final Object? error;

  @override
  Future<PatchIndex> loadPatchIndex() async {
    if (error != null) throw error!;
    return index!;
  }
}

void main() {
  final sampleIndex = PatchIndex(
    schemaVersion: 1,
    locale: 'english',
    patches: [
      PatchSummary(
        patchNumber: '7.41f',
        patchName: '7.41f',
        timestamp: 1789455600, // 2026-09-15
      ),
      PatchSummary(
        patchNumber: '7.41e',
        patchName: '7.41e',
        timestamp: 1785394800,
      ),
      PatchSummary(
        patchNumber: '7.40',
        patchName: '7.40',
        timestamp: 1765785600,
      ),
    ],
  );

  Widget createSubject({required PatchesRepository repo, GoRouter? router}) {
    final defaultRouter = GoRouter(
      initialLocation: PatchesScreen.routeLocation,
      routes: [
        GoRoute(
          path: PatchesScreen.routeLocation,
          builder: (context, state) => const PatchesScreen(),
          routes: [
            GoRoute(
              path: ':patchNumber',
              builder: (context, state) => Scaffold(
                body: Text('Detail for ${state.pathParameters['patchNumber']}'),
              ),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [patchesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router ?? defaultRouter),
    );
  }

  testWidgets('renders patch list with latest patch pinned at the top', (
    tester,
  ) async {
    final repo = _FakePatchesRepository(index: sampleIndex);

    await tester.pumpWidget(createSubject(repo: repo));
    await tester.pumpAndSettle();

    // Verify pinned latest patch is displayed
    expect(find.text('Latest Patch'), findsOneWidget);
    expect(find.text('7.41f'), findsWidgets);
    expect(find.text('September 15, 2026'), findsWidgets);

    // Verify other patches are displayed
    expect(find.text('7.41e'), findsOneWidget);
    expect(find.text('7.40'), findsOneWidget);
  });

  testWidgets('tapping pinned latest patch navigates to its detail page', (
    tester,
  ) async {
    final repo = _FakePatchesRepository(index: sampleIndex);

    await tester.pumpWidget(createSubject(repo: repo));
    await tester.pumpAndSettle();

    // Tap on the latest patch card
    await tester.tap(find.text('Latest Patch'));
    await tester.pumpAndSettle();

    expect(find.text('Detail for 7.41f'), findsOneWidget);
  });

  testWidgets('tapping an older patch item navigates to its detail page', (
    tester,
  ) async {
    final repo = _FakePatchesRepository(index: sampleIndex);

    await tester.pumpWidget(createSubject(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7.40'));
    await tester.pumpAndSettle();

    expect(find.text('Detail for 7.40'), findsOneWidget);
  });

  testWidgets('shows quiet error message when repository fails', (
    tester,
  ) async {
    final repo = _FakePatchesRepository(error: Exception('Disk failure'));

    await tester.pumpWidget(createSubject(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load patches."), findsOneWidget);
  });
}
