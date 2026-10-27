import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/services/text_stats.dart';
import '../import/import_flow.dart';
import '../library/script_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(scriptsProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Teleprompter', style: t.headlineMedium),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('New script'),
                      onPressed: () async {
                        final s = await ref
                            .read(scriptsProvider.notifier)
                            .create();
                        if (context.mounted) context.push('/editor/${s.id}');
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Import'),
                      onPressed: () => startImport(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text('Recent', style: t.titleMedium),
                const SizedBox(height: 8),
                scripts.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Could not load scripts: $e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No scripts yet. Create one to get started.',
                        ),
                      );
                    }
                    final recent = [
                      ...list,
                    ]..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
                    return Column(
                      children: [
                        for (final s in recent.take(5))
                          ScriptTile(
                            script: s,
                            subtitle:
                                '${TextStats.of(s.body).words} words · ${formatDuration(TextStats.of(s.body).estimatedDuration())}',
                            onOpen: () => context.push('/play/${s.id}'),
                            onEdit: () => context.push('/editor/${s.id}'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
