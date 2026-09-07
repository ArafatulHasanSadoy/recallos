import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
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

/// Opens a card from any surface with the same motion and a first-frame image.
/// Clearing focus keeps a search/filter keyboard from reappearing underneath
/// the card as it flies home.
Future<T?> openCardDetail<T>(
  BuildContext context, {
  required int cardId,
  required String? imagePath,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return context.push<T>(Routes.card(cardId), extra: imagePath);
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
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: Routes.capture, builder: (_, _) => const CaptureScreen()),
      // Developer scaffolding, and it stays out of shipped builds entirely.
      // The spike screen reads whatever the user picks out of the gallery,
      // runs OCR over it and writes the raw result to a file — an
      // unadvertised gallery-reading surface that Play would be right to ask
      // about. `kDebugMode` is a const, so in release the route is not
      // registered and `/spike` is unreachable even by deep link.
      if (kDebugMode)
        GoRoute(path: Routes.spike, builder: (_, _) => const SpikeScreen()),
      GoRoute(path: Routes.contacts, builder: (_, _) => const ContactsScreen()),
      GoRoute(
        path: Routes.needsAttention,
        builder: (_, _) => const NeedsAttentionScreen(),
      ),
      GoRoute(
        path: Routes.duplicates,
        builder: (_, _) => const DuplicatesScreen(),
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/person/:id',
        builder: (_, GoRouterState state) {
          final int? id = int.tryParse(state.pathParameters['id'] ?? '');
          return id == null
              ? const ContactsScreen()
              : PersonScreen(personId: id);
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
        pageBuilder: (_, GoRouterState state) {
          final int? id = int.tryParse(state.pathParameters['id'] ?? '');
          final Widget screen = id == null
              ? const HomeScreen()
              : CardDetailScreen(
                  cardId: id,
                  previewImagePath: state.extra is String
                      ? state.extra! as String
                      : null,
                );

          // A card opens out of its photograph. The page itself only fades,
          // leaving the Hero as the spatial movement; a horizontal platform
          // slide made the two motions fight and sometimes hid the expansion.
          //
          // Two layers, because the incoming page is opaque: fading it alone
          // would show the wallet through it for the whole transition. The
          // ground goes down first and the content follows, with just enough
          // overlap that they read as one move rather than two.
          //
          // The timings are the transition, so they are worth stating. The
          // wallet used to be swallowed by a flat sand wash inside the first
          // 34% — a cut, not a transition, with a card then flying over an
          // empty page for the remaining 280ms — and on the way back the wash
          // held until the flight was nearly over, so the wallet appeared
          // underneath a card that had already arrived. Now the ground
          // dissolves across the first 45%, the content lands exactly as the
          // hero does, and on the way home the content clears early so the
          // wallet is uncovered *while* the card is still travelling towards
          // its slot in it. You watch the card go back where it came from.
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: AppMotion.hero,
            reverseTransitionDuration: AppMotion.hero,
            child: screen,
            transitionsBuilder:
                (
                  BuildContext context,
                  Animation<double> animation,
                  Animation<double> secondaryAnimation,
                  Widget child,
                ) {
                  final Animation<double> ground = CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0, 0.45, curve: AppMotion.curve),
                    // Flipped, and that is not symmetry for its own sake.
                    // `easeOutCubic` front-loads, so read backwards it *holds*:
                    // on the device the sand was still 87% opaque a quarter of
                    // the way through the pop, and the wallet only appeared in
                    // the last few frames — the card landed in a slot the user
                    // had not seen yet. Flipped, the ground clears early and
                    // you watch the card go back into the stack it came from.
                    reverseCurve: Interval(
                      0,
                      0.5,
                      curve: AppMotion.curve.flipped,
                    ),
                  );
                  final Animation<double> content = CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.35, 1, curve: AppMotion.curve),
                    reverseCurve: const Interval(
                      0.55,
                      1,
                      curve: AppMotion.curve,
                    ),
                  );
                  final Color page = AppColors.of(context).page;

                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      FadeTransition(
                        opacity: ground,
                        child: ColoredBox(color: page),
                      ),
                      FadeTransition(opacity: content, child: child),
                    ],
                  );
                },
          );
        },
      ),
    ],
  );
  return router;
});
