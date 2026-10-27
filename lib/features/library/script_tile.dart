import 'package:flutter/material.dart';

import '../../domain/models/script.dart';

class ScriptTile extends StatelessWidget {
  const ScriptTile({
    super.key,
    required this.script,
    required this.subtitle,
    required this.onOpen,
    required this.onEdit,
    this.menu,
  });

  final Script script;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final Widget? menu;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(script.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(subtitle),
    onTap: onEdit,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Present',
          icon: const Icon(Icons.play_circle_outline),
          onPressed: onOpen,
        ),
        ?menu,
      ],
    ),
  );
}
