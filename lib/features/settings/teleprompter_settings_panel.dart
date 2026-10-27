import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/teleprompter_settings.dart';
import '../teleprompter/workspace_controls.dart' show modeLabels;
import 'color_picker.dart';
import 'setting_widgets.dart';

const _fonts = <String, String?>{
  'System': null,
  'Serif': 'serif',
  'Monospace': 'monospace',
};

const _colorPairs = <(String, int, int)>[
  ('White on black', 0xFFFFFFFF, 0xFF000000),
  ('Yellow on black', 0xFFFFEB3B, 0xFF000000),
  ('Green on black', 0xFF7CFC9A, 0xFF000000),
  ('Black on white', 0xFF000000, 0xFFFFFFFF),
  ('White on navy', 0xFFFFFFFF, 0xFF0B1F3A),
];

/// Live editor for [TeleprompterSettings]; used in the workspace drawer and
/// the Settings screen so both stay identical.
class TeleprompterSettingsPanel extends ConsumerWidget {
  const TeleprompterSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    void up(TeleprompterSettings Function(TeleprompterSettings) f) =>
        ref.read(settingsProvider.notifier).update(f);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const SectionHeader('Reading mode'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in modeLabels.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: s.mode == e.key,
                onSelected: (_) => up((x) => x.copyWith(mode: e.key)),
              ),
          ],
        ),
        if (s.mode == ReadingMode.paragraph)
          SliderTile(
            label: 'Paragraph hold',
            value: s.paragraphPause,
            min: 0,
            max: 15,
            format: (v) => '${v.toStringAsFixed(1)}s',
            onChanged: (v) =>
                up((x) => x.copyWith(paragraphPause: (v * 2).round() / 2)),
          ),
        if (s.mode == ReadingMode.continuous) ...[
          SliderTile(
            label: 'Pause every',
            value: s.autoPauseEvery.toDouble(),
            min: 0,
            max: 120,
            divisions: 24,
            format: (v) => v == 0 ? 'off' : '${v.round()}s',
            onChanged: (v) => up((x) => x.copyWith(autoPauseEvery: v.round())),
          ),
          if (s.autoPauseEvery > 0)
            SliderTile(
              label: 'Pause for',
              value: s.autoPauseFor.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              format: (v) => '${v.round()}s',
              onChanged: (v) => up((x) => x.copyWith(autoPauseFor: v.round())),
            ),
        ],
        const SectionHeader('Speed'),
        SliderTile(
          label: 'Seconds per line',
          value: s.secondsPerLine,
          min: 0.3,
          max: 10,
          format: (v) => '${v.toStringAsFixed(1)}s',
          onChanged: (v) =>
              up((x) => x.copyWith(secondsPerLine: (v * 10).round() / 10)),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final e in TeleprompterSettings.speedPresets.entries)
              ChoiceChip(
                label: Text('${e.key} · ${e.value}s'),
                selected: s.secondsPerLine == e.value,
                onSelected: (_) =>
                    up((x) => x.copyWith(secondsPerLine: e.value)),
              ),
          ],
        ),
        SliderTile(
          label: 'Countdown',
          value: s.countdownSeconds.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          format: (v) => '${v.round()}s',
          onChanged: (v) => up((x) => x.copyWith(countdownSeconds: v.round())),
        ),
        const SectionHeader('Typography'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SegmentedButton<String?>(
            showSelectedIcon: false,
            segments: [
              for (final e in _fonts.entries)
                ButtonSegment(value: e.value, label: Text(e.key)),
            ],
            selected: {s.fontFamily},
            onSelectionChanged: (v) =>
                up((x) => x.copyWith(fontFamily: v.first)),
          ),
        ),
        SliderTile(
          label: 'Font size',
          value: s.fontSize,
          min: 16,
          max: 140,
          format: (v) => '${v.round()}',
          onChanged: (v) => up((x) => x.copyWith(fontSize: v.roundToDouble())),
        ),
        SliderTile(
          label: 'Weight',
          value: s.fontWeight.toDouble(),
          min: 100,
          max: 900,
          divisions: 8,
          format: (v) => '${v.round()}',
          onChanged: (v) => up((x) => x.copyWith(fontWeight: v.round())),
        ),
        SliderTile(
          label: 'Line height',
          value: s.lineHeight,
          min: 1,
          max: 2.5,
          format: (v) => v.toStringAsFixed(2),
          onChanged: (v) => up((x) => x.copyWith(lineHeight: v)),
        ),
        SliderTile(
          label: 'Letter spacing',
          value: s.letterSpacing,
          min: -1,
          max: 8,
          format: (v) => v.toStringAsFixed(1),
          onChanged: (v) => up((x) => x.copyWith(letterSpacing: v)),
        ),
        SliderTile(
          label: 'Paragraph gap',
          value: s.paragraphSpacing,
          min: 0,
          max: 100,
          format: (v) => '${v.round()}',
          onChanged: (v) =>
              up((x) => x.copyWith(paragraphSpacing: v.roundToDouble())),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Italic'),
          value: s.italic,
          onChanged: (v) => up((x) => x.copyWith(italic: v)),
        ),
        const SectionHeader('Layout'),
        SegmentedButton<ReadAlign>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ReadAlign.left,
              icon: Icon(Icons.format_align_left),
              tooltip: 'Left',
            ),
            ButtonSegment(
              value: ReadAlign.center,
              icon: Icon(Icons.format_align_center),
              tooltip: 'Center',
            ),
            ButtonSegment(
              value: ReadAlign.right,
              icon: Icon(Icons.format_align_right),
              tooltip: 'Right',
            ),
            ButtonSegment(
              value: ReadAlign.justify,
              icon: Icon(Icons.format_align_justify),
              tooltip: 'Justify',
            ),
          ],
          selected: {s.align},
          onSelectionChanged: (v) => up((x) => x.copyWith(align: v.first)),
        ),
        SliderTile(
          label: 'Reading width',
          value: s.readingWidth,
          min: 0.3,
          max: 1,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(readingWidth: v)),
        ),
        SliderTile(
          label: 'Side margin',
          value: s.horizontalMargin,
          min: 0,
          max: 120,
          format: (v) => '${v.round()}',
          onChanged: (v) =>
              up((x) => x.copyWith(horizontalMargin: v.roundToDouble())),
        ),
        SliderTile(
          label: 'Reading line',
          value: s.guidePosition,
          min: 0.1,
          max: 0.9,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(guidePosition: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show reading line'),
          value: s.showGuide,
          onChanged: (v) => up((x) => x.copyWith(showGuide: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Right-to-left text'),
          value: s.rtl,
          onChanged: (v) => up((x) => x.copyWith(rtl: v)),
        ),
        const SectionHeader('Display'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, fg, bg) in _colorPairs)
              ChoiceChip(
                avatar: CircleAvatar(
                  backgroundColor: Color(bg),
                  child: Text(
                    'A',
                    style: TextStyle(color: Color(fg), fontSize: 12),
                  ),
                ),
                label: Text(name),
                selected: s.textColor == fg && s.backgroundColor == bg,
                onSelected: (_) =>
                    up((x) => x.copyWith(textColor: fg, backgroundColor: bg)),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(s.textColor),
                ),
                label: const Text('Text colour'),
                onPressed: () async {
                  final c = await pickColor(
                    context,
                    'Text colour',
                    s.textColor,
                  );
                  if (c != null) up((x) => x.copyWith(textColor: c));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: CircleAvatar(
                  radius: 8,
                  backgroundColor: Color(s.backgroundColor),
                ),
                label: const Text('Background'),
                onPressed: () async {
                  final c = await pickColor(
                    context,
                    'Background colour',
                    s.backgroundColor,
                  );
                  if (c != null) up((x) => x.copyWith(backgroundColor: c));
                },
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mirror horizontally'),
          subtitle: const Text('For beam-splitter glass rigs'),
          value: s.mirrorHorizontal,
          onChanged: (v) => up((x) => x.copyWith(mirrorHorizontal: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Flip vertically'),
          value: s.flipVertical,
          onChanged: (v) => up((x) => x.copyWith(flipVertical: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hide controls while playing'),
          value: s.autoHideControls,
          onChanged: (v) => up((x) => x.copyWith(autoHideControls: v)),
        ),
        const SectionHeader('Picture-in-picture (Android)'),
        SliderTile(
          label: 'PiP text size',
          value: s.pipFontScale,
          min: 0.3,
          max: 1.2,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(pipFontScale: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Portrait window'),
          value: s.pipPortrait,
          onChanged: (v) => up((x) => x.copyWith(pipPortrait: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enter PiP when leaving the app'),
          subtitle: const Text('Only while the script is playing'),
          value: s.autoPip,
          onChanged: (v) => up((x) => x.copyWith(autoPip: v)),
        ),
        const SectionHeader('Display profiles'),
        const _Profiles(),
      ],
    );
  }
}

class _Profiles extends ConsumerWidget {
  const _Profiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in profiles)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.name),
            onTap: () => ref.read(profilesProvider.notifier).apply(p),
            trailing: IconButton(
              tooltip: 'Delete profile',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(profilesProvider.notifier).remove(p.name),
            ),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save current as profile'),
          onPressed: () async {
            final c = TextEditingController();
            final name = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Profile name'),
                content: TextField(
                  controller: c,
                  autofocus: true,
                  onSubmitted: (v) => Navigator.pop(ctx, v),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, c.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            if (name != null && name.trim().isNotEmpty) {
              ref.read(profilesProvider.notifier).saveCurrent(name.trim());
            }
          },
        ),
      ],
    );
  }
}
