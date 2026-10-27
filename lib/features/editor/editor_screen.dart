import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/services/text_stats.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.scriptId});
  final String scriptId;
  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  Timer? _debounce;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(scriptByIdProvider(widget.scriptId));
    _title = TextEditingController(text: s?.title ?? '');
    _body = TextEditingController(text: s?.body ?? '');
    _loaded = s != null;
    _body.addListener(() => setState(() {}));
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    if (!_loaded) return;
    await ref
        .read(scriptsProvider.notifier)
        .edit(
          widget.scriptId,
          title: _title.text.trim().isEmpty
              ? 'Untitled script'
              : _title.text.trim(),
          body: _body.text,
        );
  }

  @override
  void dispose() {
    // Persist any pending edit; fire-and-forget is fine, the repo write is atomic.
    if (_debounce?.isActive ?? false) _flush();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final script = ref.watch(scriptByIdProvider(widget.scriptId));
    if (script == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Script not found.')),
      );
    }
    final stats = TextStats.of(_body.text);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _title,
          onChanged: (_) => _scheduleSave(),
          style: Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Title',
            filled: false,
          ),
        ),
        actions: [
          if (script.isModifiedFromOriginal)
            IconButton(
              tooltip: 'Restore original import',
              icon: const Icon(Icons.restore),
              onPressed: () {
                _body.text = script.originalBody!;
                _scheduleSave();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Present'),
              onPressed: () async {
                await _flush();
                if (context.mounted) context.push('/play/${widget.scriptId}');
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _body,
                    onChanged: (_) => _scheduleSave(),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 17, height: 1.5),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      hintText: 'Type or paste your script. Leave a blank line between paragraphs.',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${stats.words} words · ${stats.characters} characters · ${stats.paragraphs} paragraphs · ~${formatDuration(stats.estimatedDuration())} at 150 wpm',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
