import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/providers.dart';

class NavItem {
  const NavItem(this.path, this.icon, this.label, {this.adminOnly = false});
  final String path;
  final IconData icon;
  final String label;
  final bool adminOnly;
}

const navItems = [
  NavItem('/', Icons.home_outlined, 'Home'),
  NavItem('/puzzles', Icons.extension_outlined, 'Puzzle'),
  NavItem('/storm', Icons.bolt_outlined, 'Storm'),
  NavItem('/play', Icons.sports_esports_outlined, 'Gioca'),
  NavItem('/openings', Icons.menu_book_outlined, 'Aperture'),
  NavItem('/games', Icons.history, 'Partite'),
  NavItem('/analysis', Icons.manage_search, 'Analisi'),
  NavItem('/stats', Icons.insights_outlined, 'Statistiche'),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final items = navItems.where((i) => !i.adminOnly || (user?.isAdmin ?? false)).toList();
    var selected = items.lastIndexWhere((i) => i.path == '/' ? location == '/' : location.startsWith(i.path));
    if (selected < 0) selected = 0;
    final wide = MediaQuery.sizeOf(context).width >= 800;

    final appBar = AppBar(
      title: const Text('Chess Mentor'),
      actions: [
        if (user != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(user.email)),
              const PopupMenuItem(value: 'logout', child: Text('Esci')),
            ],
            onSelected: (v) {
              if (v == 'logout') ref.read(authProvider.notifier).logout();
            },
          ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          NavigationRail(
            selectedIndex: selected,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) => context.go(items[i].path),
            destinations: [
              for (final i in items) NavigationRailDestination(icon: Icon(i.icon), label: Text(i.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => context.go(items[i].path),
        destinations: [
          for (final i in items) NavigationDestination(icon: Icon(i.icon), label: i.label),
        ],
      ),
    );
  }
}
