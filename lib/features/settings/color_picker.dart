import 'package:flutter/material.dart';

/// Small RGB colour picker dialog (no extra dependency). Returns ARGB int.
Future<int?> pickColor(BuildContext context, String title, int initial) {
  var c = Color(initial);
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Widget ch(String label, double v, Color tint, ValueChanged<double> f) =>
            Row(
              children: [
                SizedBox(width: 20, child: Text(label)),
                Expanded(
                  child: Slider(
                    value: v,
                    min: 0,
                    max: 255,
                    activeColor: tint,
                    onChanged: (x) => setState(() => f(x)),
                  ),
                ),
                SizedBox(width: 32, child: Text('${v.round()}')),
              ],
            );
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(ctx).colorScheme.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  style: TextStyle(
                    color: c.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
              ch(
                'R',
                c.r * 255,
                Colors.red,
                (x) => c = Color.from(
                  alpha: 1,
                  red: x / 255,
                  green: c.g,
                  blue: c.b,
                ),
              ),
              ch(
                'G',
                c.g * 255,
                Colors.green,
                (x) => c = Color.from(
                  alpha: 1,
                  red: c.r,
                  green: x / 255,
                  blue: c.b,
                ),
              ),
              ch(
                'B',
                c.b * 255,
                Colors.blue,
                (x) => c = Color.from(
                  alpha: 1,
                  red: c.r,
                  green: c.g,
                  blue: x / 255,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.toARGB32()),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}
