import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/capture/presentation/capture_screen.dart';
import 'features/capture/presentation/spike_screen.dart';
import 'features/cards/presentation/card_detail_screen.dart';
import 'features/cards/presentation/needs_attention_screen.dart';
import 'features/contacts/presentation/contacts_screen.dart';
import 'features/contacts/presentation/duplicates_screen.dart';
import 'features/contacts/presentation/organization_screen.dart';
import 'features/contacts/presentation/person_screen.dart';
import 'features/search/presentation/home_screen.dart';
import 'features/settings/data/app_settings.dart';
import 'features/settings/presentation/onboarding_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

/// Route paths, in one place so links never drift apart from the router.
abstract final class Routes {
  static const String home = '/';
  static const String capture = '/capture';
  static const String contacts = '/contacts';
  static const String duplicates = '/duplicates';
  static const String needsAttention = '/needs-attention';
  static const String settings = '/settings';
  static const String onboarding = '/welcome';

  /// Phase 0 scaffolding. Delete once the OCR gate has been answered.
  static const String spike = '/spike';

  /// One saved card. Built rather than hard-coded so the id cannot be
  /// interpolated in two different shapes across the app.
  static String card(int id) => '/card/$id';

  /// One person in the identity graph.
  static String person(int id) => '/person/$id';

  /// One company in the identity graph.
  static String organization(int id) => '/org/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  late final GoRouter router;
  // Re-runs the redirect when the stored settings arrive a frame after launch.
  // Without this the router would have decided the first-run question against
  // defaults and never revisited it.
  ref.listen(appSettingsProvider, (AppSettings? before, AppSettings after) {
    if (before?.loaded != after.loaded) router.refresh();
  });

  router = GoRouter(
    initialLocation: Routes.home,
    // First run goes through the three panels once, and only once.
    //
    // A redirect rather than a different `initialLocation`, because the flag
    // is read from the database a frame after launch: starting at home and
    // being moved is correct either way round, where choosing a start location
    // against an unloaded flag would show onboarding to everybody.
    redirect: (_, GoRouterState state) {
      final AppSettings settings = ref.read(appSettingsProvider);
      // Nothing is known yet, so nothing is decided. The router is refreshed
      // below when the read lands.
      if (!settings.loaded) return null;
      if (settings.onboarded || state.matchedLocation == Routes.onboarding) {
        return null;
      }
      return state.matchedLocation == Routes.home ? Routes.onboarding : null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.capture,
        builder: (_, _) => const CaptureScreen(),
      ),
      GoRoute(
        path: Routes.spike,
        builder: (_, _) => const SpikeScreen(),
      ),
      GoRoute(
        path: Routes.contacts,
        builder: (_, _) => const ContactsScreen(),
      ),
      GoRoute(
        path: Routes.needsAttention,
        builder: (_, _) => const NeedsAttentionScreen(),
      ),
      GoRoute(
        path: Routes.duplicates,
        builder: (_, _) => const DuplicatesScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, GoRouterState state) {
          final int? id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null ? const ContactsScreen() : PersonScreen(personId: id);
        },
      ),
      GoRoute(
        path: '/org/:id',
        builder: (_, GoRouterState state) {
          final int? id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? const ContactsScreen()
              : OrganizationScreen(orgId: id);
        },
      ),
      GoRoute(
        path: '/card/:id',
        builder: (_, GoRouterState state) {
          final int? id = int.tryParse(state.pathParameters['id'] ?? '');
          // A malformed id lands on the home screen rather than crashing.
          return id == null
              ? const HomeScreen()
              : CardDetailScreen(cardId: id);
        },
      ),
    ],
  );
  return router;
});
