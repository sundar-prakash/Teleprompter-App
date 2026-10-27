import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/breakpoints.dart';
import '../../domain/models/script.dart';
import '../../domain/services/text_stats.dart';
import '../import/import_flow.dart';
import 'script_tile.dart';

enum _Sort { recent, name, modified }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  _Sort _sort = _Sort.recent;

  List<Script> _apply(List<Script> all) {
    final q = _query.toLowerCase();
    final l = all
        .where(
          (s) =>
              q.isEmpty ||
              s.title.toLowerCase().contains(q) ||
              s.body.toLowerCase().contains(q),
        )
        .toList();
    l.sort(switch (_sort) {
      _Sort.recent => (a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt),
      _Sort.name => (a, b) => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
      _Sort.modified => (a, b) => b.updatedAt.compareTo(a.updatedAt),
    });
    return l;
  }

  Future<void> _rename(Script s) async {
    final c = TextEditingController(text: s.title);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename script'),
        content: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(scriptsProvider.notifier).edit(s.id, title: name.trim());
    }
  }

  Future<void> _delete(Script s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete script?'),
        content: Text('"${s.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(scriptsProvider.notifier).delete(s.id);
  }

  Widget _menu(Script s) => PopupMenuButton<String>(
    onSelected: (v) => switch (v) {
      'rename' => _rename(s),
      'dup' => ref.read(scriptsProvider.notifier).duplicate(s.id),
      _ => _delete(s),
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'rename', child: Text('Rename')),
      PopupMenuItem(value: 'dup', child: Text('Duplicate')),
      PopupMenuItem(value: 'del', child: Text('Delete')),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scripts = ref.watch(scriptsProvider);
    final grid = ref.watch(libraryGridProvider);
    final wc = context.windowClass;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Import document',
            icon: const Icon(Icons.upload_file),
            onPressed: () => startImport(context),
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _Sort.recent,
                child: Text('Recently opened'),
              ),
              PopupMenuItem(
                value: _Sort.modified,
                child: Text('Last modified'),
              ),
              PopupMenuItem(value: _Sort.name, child: Text('Name')),
            ],
          ),
          IconButton(
            tooltip: grid ? 'List view' : 'Grid view',
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            onPressed: () => ref.read(libraryGridProvider.notifier).set(!grid),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New script',
        onPressed: () async {
          final s = await ref.read(scriptsProvider.notifier).create();
          if (context.mounted) context.push('/editor/${s.id}');
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search scripts',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: scripts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Could not load scripts: $e')),
              data: (all) {
                final list = _apply(all);
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty ? 'Your library is empty.' : 'No matches.',
                    ),
                  );
                }
                String sub(Script s) {
                  final st = TextStats.of(s.body);
                  return '${st.words} words · ${formatDuration(st.estimatedDuration())}';
                }

                if (!grid) {
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, i) => ScriptTile(
                      script: list[i],
                      subtitle: sub(list[i]),
                      menu: _menu(list[i]),
                      onOpen: () => context.push('/play/${list[i].id}'),
                      onEdit: () => context.push('/editor/${list[i].id}'),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: wc == WindowClass.compact ? 220 : 300,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/editor/${s.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  _menu(s),
                                ],
                              ),
                              Expanded(
                                child: Text(
                                  s.body,
                                  overflow: TextOverflow.fade,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      sub(s),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Present',
                                    icon: const Icon(Icons.play_circle_outline),
                                    onPressed: () =>
                                        context.push('/play/${s.id}'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
