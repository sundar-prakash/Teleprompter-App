import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/editor/editor_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/teleprompter/teleprompter_screen.dart';
import '../data/importers/import_result.dart';
import '../features/import/import_preview_screen.dart';
import '../features/camera/camera_screen.dart';
import 'shell.dart';

GoRouter buildRouter() => GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, nav) => AppShell(navigationShell: nav),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Outside the shell: no app chrome competes with the script.
    GoRoute(
      path: '/editor/:id',
      builder: (_, st) => EditorScreen(scriptId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/import-preview',
      builder: (_, st) =>
          ImportPreviewScreen(result: st.extra! as ImportResult),
    ),
    GoRoute(
      path: '/camera/:id',
      builder: (_, st) => CameraScreen(scriptId: st.pathParameters['id']!),
    ),
    GoRoute(
      path: '/play/:id',
      builder: (_, st) =>
          TeleprompterScreen(scriptId: st.pathParameters['id']!),
    ),
  ],
  errorBuilder: (_, st) =>
      Scaffold(body: Center(child: Text('Page not found: ${st.uri}'))),
);
