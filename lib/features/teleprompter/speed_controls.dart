import 'package:flutter/material.dart';

import '../../domain/models/teleprompter_settings.dart';

/// Pace control that can't be misread: two labelled buttons (Slower / Faster)
/// around the current pace in seconds per line. Pressing "Faster" lowers the
/// seconds shown, because less time per line is a faster pace.
class SpeedControls extends StatelessWidget {
  const SpeedControls({
    super.key,
    required this.secondsPerLine,
    required this.onSlower,
    required this.onFaster,
    this.color = Colors.white,
  });

  final double secondsPerLine;
  final VoidCallback onSlower;
  final VoidCallback onFaster;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cap = TextStyle(
      color: color.withValues(alpha: 0.75),
      fontSize: 11,
      height: 1,
    );
    Widget button(IconData icon, String label, VoidCallback f) => InkResponse(
      onTap: f,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(label, style: cap),
          ],
        ),
      ),
    );
    return Semantics(
      label:
          'Reading pace ${secondsPerLine.toStringAsFixed(1)} seconds per line',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.directions_walk, 'Slower', onSlower),
          SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  secondsPerLine.toStringAsFixed(1),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                Text('sec / line', style: cap),
              ],
            ),
          ),
          button(Icons.directions_run, 'Faster', onFaster),
        ],
      ),
    );
  }
}

/// Shared helper so every screen nudges pace the same way.
TeleprompterSettings nudgePace(
  TeleprompterSettings s, {
  required bool faster,
}) => s.copyWith(
  secondsPerLine: TeleprompterSettings.nudgeSeconds(
    s.secondsPerLine,
    faster: faster,
  ),
);
