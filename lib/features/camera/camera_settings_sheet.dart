import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/camera_prefs.dart';
import '../settings/setting_widgets.dart';

/// [onChanged] is called after a change that needs the camera to restart
/// (resolution / frame rate); null while recording to block those changes.
Future<void> showCameraSettings(
  BuildContext context, {
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, sc) => _Sheet(scroll: sc, onChanged: onChanged),
    ),
  );
}

class _Sheet extends ConsumerWidget {
  const _Sheet({required this.scroll, required this.onChanged});
  final ScrollController scroll;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(cameraPrefsProvider);
    void up(CameraPrefs Function(CameraPrefs) f) =>
        ref.read(cameraPrefsProvider.notifier).update(f);
    final locked = onChanged == null;

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const SectionHeader('Layout'),
        RadioGroup<CameraLayout>(
          groupValue: p.layout,
          onChanged: (v) => up((x) => x.copyWith(layout: v)),
          child: Column(
            children: [
              for (final l in CameraLayout.values)
                RadioListTile<CameraLayout>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.label),
                  value: l,
                ),
            ],
          ),
        ),
        SliderTile(
          label: 'Script area',
          value: p.scriptHeight,
          min: 0.15,
          max: 0.7,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(scriptHeight: v)),
        ),
        SliderTile(
          label: 'Position',
          value: p.scriptOffset,
          min: 0,
          max: 0.8,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(scriptOffset: v)),
        ),
        SliderTile(
          label: 'Background',
          value: p.scriptOpacity,
          min: 0,
          max: 1,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(scriptOpacity: v)),
        ),
        SliderTile(
          label: 'Text size',
          value: p.fontScale,
          min: 0.3,
          max: 1.2,
          format: (v) => '${(v * 100).round()}%',
          onChanged: (v) => up((x) => x.copyWith(fontScale: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Stop recording when script ends'),
          value: p.stopWithScript,
          onChanged: (v) => up((x) => x.copyWith(stopWithScript: v)),
        ),
        const SectionHeader('Video'),
        if (locked)
          const Text(
            'Resolution and frame rate can\'t change while recording.',
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final q in VideoQuality.values)
              ChoiceChip(
                label: Text(q.label),
                selected: p.quality == q,
                onSelected: locked
                    ? null
                    : (_) {
                        up((x) => x.copyWith(quality: q));
                        onChanged!();
                      },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in const [24, 30, 60])
              ChoiceChip(
                label: Text('$f fps'),
                selected: p.fps == f,
                onSelected: locked
                    ? null
                    : (_) {
                        up((x) => x.copyWith(fps: f));
                        onChanged!();
                      },
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'If your device can\'t record at the chosen resolution or frame rate, the app steps down automatically and tells you.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
