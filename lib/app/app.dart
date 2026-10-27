import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import 'providers.dart';
import 'router.dart';

class TeleprompterApp extends ConsumerStatefulWidget {
  const TeleprompterApp({super.key});
  @override
  ConsumerState<TeleprompterApp> createState() => _TeleprompterAppState();
}

class _TeleprompterAppState extends ConsumerState<TeleprompterApp> {
  late final GoRouter _router = buildRouter();

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Teleprompter',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: _router,
  );
}
