import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/importers/import_result.dart';
import '../../domain/models/script.dart';
import '../../domain/services/text_stats.dart';

class ImportPreviewScreen extends ConsumerStatefulWidget {
  const ImportPreviewScreen({super.key, required this.result});
  final ImportResult result;
  @override
  ConsumerState<ImportPreviewScreen> createState() =>
      _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen> {
  late final _title = TextEditingController(text: widget.result.title);
  bool _keepTiming = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save({required bool present}) async {
    setState(() => _saving = true);
    final r = widget.result;
    final s = await ref
        .read(scriptsProvider.notifier)
        .create(
          title: _title.text.trim().isEmpty ? r.title : _title.text.trim(),
          body: r.text,
          format: r.format,
          fileName: r.fileName,
          cues: _keepTiming ? r.cues : const [],
        );
    if (!mounted) return;
    context.pushReplacement(present ? '/play/${s.id}' : '/editor/${s.id}');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final stats = TextStats.of(r.text);
    final paragraphs = splitParagraphs(r.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Preview import')),
      // Header and preview scroll together, so the screen still fits on
      // small phones, with large system text, or with the keyboard open.
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        TextField(
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: 'Script title',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${r.fileName} · ${r.format.name.toUpperCase()} · ${stats.words} words · ~${formatDuration(stats.estimatedDuration())}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        for (final w in r.warnings)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              w,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (r.format == SourceFormat.srt)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Keep subtitle timing'),
                            subtitle: const Text(
                              'Off: plain continuous script. On: also enables Subtitle mode, which shows each line at its timestamp.',
                            ),
                            value: _keepTiming,
                            onChanged: (v) => setState(() => _keepTiming = v),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider()),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.builder(
                    itemCount: paragraphs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        paragraphs[i],
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              // One row when it fits; stacked (primary on top) on narrow
              // screens or with large system text.
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                overflowDirection: VerticalDirection.up,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => context.pop(),
                    child: const Text('Cancel'),
                  ),
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save(present: false),
                    child: const Text('Save & edit'),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(present: true),
                    child: const Text('Save & present'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
