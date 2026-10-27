import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/teleprompter_settings.dart';
import '../../domain/services/text_stats.dart';
import 'playback_controller.dart';

const modeLabels = {
  ReadingMode.continuous: 'Continuous',
  ReadingMode.singleLine: 'Single line',
  ReadingMode.paragraph: 'Paragraph',
  ReadingMode.manual: 'Manual',
  ReadingMode.subtitle: 'Subtitle',
};

class WorkspaceControls extends ConsumerWidget {
  const WorkspaceControls({
    super.key,
    required this.pc,
    required this.title,
    required this.hasCues,
    required this.onClose,
    required this.onSettings,
    required this.onInteract,
    required this.onBookmarks,
    required this.menuItems,
    required this.onMenu,
  });

  final PlaybackController pc;
  final String title;
  final bool hasCues;
  final VoidCallback onClose;
  final VoidCallback onSettings;
  final VoidCallback onInteract;
  final VoidCallback onBookmarks;
  final List<PopupMenuEntry<String>> menuItems;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    Widget bar(Widget child, {required bool top}) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.78), Colors.transparent],
        ),
      ),
      child: SafeArea(child: child),
    );
    void speed({required bool faster}) {
      ref
          .read(settingsProvider.notifier)
          .update(
            (x) => x.copyWith(
              secondsPerLine: TeleprompterSettings.nudgeSeconds(
                x.secondsPerLine,
                faster: faster,
              ),
            ),
          );
      onInteract();
    }

    final px = s.fontSize * s.lineHeight * 4;
    const dim = TextStyle(color: Colors.white70, fontSize: 12);

    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F8F7B),
          brightness: Brightness.dark,
        ),
      ),
      child: Column(
        children: [
          bar(
            top: true,
            Row(
              children: [
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onClose,
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                IconButton(
                  tooltip: 'Mirror horizontally',
                  isSelected: s.mirrorHorizontal,
                  icon: const Icon(Icons.flip),
                  onPressed: () {
                    ref
                        .read(settingsProvider.notifier)
                        .update(
                          (x) =>
                              x.copyWith(mirrorHorizontal: !x.mirrorHorizontal),
                        );
                    onInteract();
                  },
                ),
                IconButton(
                  tooltip: 'Flip vertically',
                  isSelected: s.flipVertical,
                  icon: const RotatedBox(
                    quarterTurns: 1,
                    child: Icon(Icons.flip),
                  ),
                  onPressed: () {
                    ref
                        .read(settingsProvider.notifier)
                        .update(
                          (x) => x.copyWith(flipVertical: !x.flipVertical),
                        );
                    onInteract();
                  },
                ),
                IconButton(
                  tooltip: 'Bookmarks',
                  icon: const Icon(Icons.bookmarks_outlined),
                  onPressed: onBookmarks,
                ),
                IconButton(
                  tooltip: 'Display & playback',
                  icon: const Icon(Icons.tune),
                  onPressed: onSettings,
                ),
                PopupMenuButton<String>(
                  onSelected: onMenu,
                  itemBuilder: (_) => menuItems,
                ),
              ],
            ),
          ),
          const Spacer(),
          bar(
            top: false,
            ListenableBuilder(
              listenable: pc,
              builder: (_, _) {
                final rem = pc.estimatedRemaining;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 28, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pc.isHolding)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Holding · ${pc.holdRemaining}s',
                            style: dim,
                          ),
                        ),
                      Row(
                        children: [
                          Text(formatDuration(pc.elapsed), style: dim),
                          Expanded(
                            child: Slider(
                              value: pc.progress,
                              onChanged: (v) {
                                pc.seek(v);
                                onInteract();
                              },
                            ),
                          ),
                          Text(
                            rem == null ? '–' : '−${formatDuration(rem)}',
                            style: dim,
                          ),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'Restart',
                            icon: const Icon(Icons.replay),
                            onPressed: pc.restart,
                          ),
                          IconButton(
                            tooltip: 'Back',
                            icon: const Icon(Icons.skip_previous),
                            onPressed: () => pc.jump(-1, px),
                          ),
                          IconButton.filled(
                            iconSize: 34,
                            tooltip: pc.isPlaying ? 'Pause' : 'Play',
                            icon: Icon(
                              pc.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            onPressed: pc.canAutoPlay ? pc.toggle : null,
                          ),
                          IconButton(
                            tooltip: 'Forward',
                            icon: const Icon(Icons.skip_next),
                            onPressed: () => pc.jump(1, px),
                          ),
                          IconButton(
                            tooltip: 'Stop',
                            icon: const Icon(Icons.stop),
                            onPressed: pc.stop,
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: 'Slower (more seconds per line)',
                            icon: const Icon(Icons.remove),
                            onPressed: () => speed(faster: false),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '${s.secondsPerLine.toStringAsFixed(1)} s\nper line',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                height: 1.1,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Faster (fewer seconds per line)',
                            icon: const Icon(Icons.add),
                            onPressed: () => speed(faster: true),
                          ),
                          PopupMenuButton<ReadingMode>(
                            tooltip: 'Reading mode',
                            initialValue: s.mode,
                            onSelected: (m) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .update((x) => x.copyWith(mode: m));
                              onInteract();
                            },
                            itemBuilder: (_) => [
                              for (final e in modeLabels.entries)
                                PopupMenuItem(
                                  value: e.key,
                                  enabled:
                                      e.key != ReadingMode.subtitle || hasCues,
                                  child: Text(
                                    e.key == ReadingMode.subtitle && !hasCues
                                        ? 'Subtitle (needs an SRT script)'
                                        : e.value,
                                  ),
                                ),
                            ],
                            child: Chip(
                              avatar: const Icon(Icons.view_stream, size: 16),
                              label: Text(modeLabels[pc.mode]!),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
