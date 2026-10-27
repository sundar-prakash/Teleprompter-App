import 'package:flutter/material.dart';

class SliderTile extends StatelessWidget {
  const SliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 112, child: Text(label, style: t.bodyMedium)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              semanticFormatterCallback: format,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              format?.call(value) ?? value.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: t.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
