import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/breakpoints.dart';

const _dests = [
  (Icons.home_outlined, Icons.home, 'Home'),
  (Icons.video_library_outlined, Icons.video_library, 'Library'),
  (Icons.settings_outlined, Icons.settings, 'Settings'),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final wc = context.windowClass;
    void go(int i) => navigationShell.goBranch(
      i,
      initialLocation: i == navigationShell.currentIndex,
    );

    if (wc == WindowClass.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: go,
          destinations: [
            for (final d in _dests)
              NavigationDestination(
                icon: Icon(d.$1),
                selectedIcon: Icon(d.$2),
                label: d.$3,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: wc == WindowClass.expanded,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: go,
            labelType: wc == WindowClass.expanded
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(
                  icon: Icon(d.$1),
                  selectedIcon: Icon(d.$2),
                  label: Text(d.$3),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
