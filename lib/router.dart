import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api/models.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/play/play_page.dart';
import 'features/puzzle/puzzle_page.dart';
import 'features/stats/stats_page.dart';
import 'features/storm/storm_page.dart';
import 'state/providers.dart';
import 'widgets/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<User?>>(ref.read(authProvider));
  ref.listen(authProvider, (_, next) => auth.value = next);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final a = auth.value;
      final loc = state.matchedLocation;
      // durante il ripristino della sessione si ricorda la destinazione (deep link / reload)
      if (a.isLoading) {
        return loc == '/splash' ? null : Uri(path: '/splash', queryParameters: {'from': state.uri.toString()}).toString();
      }
      final loggedIn = a.value != null;
      final from = state.uri.queryParameters['from'];
      if (!loggedIn) {
        if (loc == '/login') return null;
        return Uri(path: '/login', queryParameters: {
          if (loc != '/splash' && loc != '/') 'from': state.uri.toString(),
          if (loc == '/splash' && from != null) 'from': from,
        }).toString();
      }
      if (loc == '/login' || loc == '/splash') return from ?? '/';
      if (loc.startsWith('/admin') && a.value?.isAdmin != true) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
          GoRoute(
            path: '/puzzles',
            builder: (_, s) => PuzzlePage(
              key: ValueKey(s.uri.toString()),
              initialMode: s.uri.queryParameters['mode'],
              initialTheme: s.uri.queryParameters['theme'],
              puzzleId: s.uri.queryParameters['id'],
            ),
          ),
          GoRoute(path: '/storm', builder: (_, __) => const StormPage()),
          GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
          GoRoute(path: '/play', builder: (_, __) => const PlayPage(key: ValueKey('new'))),
          GoRoute(path: '/play/:id', builder: (_, s) => PlayPage(key: ValueKey(s.pathParameters['id']), gameId: s.pathParameters['id'])),
          ...extraRoutes,
        ],
      ),
    ],
  );
});

/// Rotte aggiunte dalle fasi successive.
final List<RouteBase> extraRoutes = [];
