import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/capture/presentation/capture_screen.dart';
import 'features/capture/presentation/spike_screen.dart';
import 'features/cards/presentation/card_detail_screen.dart';
import 'features/search/presentation/home_screen.dart';

/// Route paths, in one place so links never drift apart from the router.
abstract final class Routes {
  static const String home = '/';
  static const String capture = '/capture';
  static const String needsAttention = '/needs-attention';
  static const String settings = '/settings';

  /// Phase 0 scaffolding. Delete once the OCR gate has been answered.
  static const String spike = '/spike';

  /// One saved card. Built rather than hard-coded so the id cannot be
  /// interpolated in two different shapes across the app.
  static String card(int id) => '/card/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
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
});
