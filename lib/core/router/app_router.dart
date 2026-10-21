import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/heroes/hero_detail_screen.dart';
import '../../features/heroes/heroes_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/items/item_detail_screen.dart';
import '../../features/items/items_screen.dart';
import '../../features/patches/patch_detail_screen.dart';
import '../../features/patches/patches_screen.dart';
import '../shell/app_shell.dart';

/// The app's single navigation configuration, exposed as a Riverpod provider
/// so it is the one place routes are declared and tests can override it.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: HomeScreen.routeLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeScreen.routeLocation,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HeroesScreen.routeLocation,
                builder: (context, state) => const HeroesScreen(),
                // Detail nests inside the Heroes tab: pushing it keeps the
                // tab shell (back returns to the grid), per the spec's
                // grid → detail navigation.
                routes: [
                  GoRoute(
                    path: HeroDetailScreen.routePath,
                    builder: (context, state) => HeroDetailScreen(
                      heroId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ItemsScreen.routeLocation,
                builder: (context, state) => const ItemsScreen(),
                // Detail nests inside the Items tab: pushing it keeps the
                // tab shell (back returns to the list), same as Heroes.
                routes: [
                  GoRoute(
                    path: ItemDetailScreen.routePath,
                    builder: (context, state) => ItemDetailScreen(
                      itemId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: PatchesScreen.routeLocation,
                builder: (context, state) => const PatchesScreen(),
                // Detail nests inside the Patches tab: pushing it keeps the
                // tab shell (back returns to the list), same as Heroes and Items.
                routes: [
                  GoRoute(
                    path: PatchDetailScreen.routePath,
                    builder: (context, state) => PatchDetailScreen(
                      patchNumber: state.pathParameters['patchNumber']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // About sits outside the tab shell: it is pushed from Home's top-bar
      // menu, per the spec's navigation decision.
      GoRoute(
        path: AboutScreen.routeLocation,
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );
});
