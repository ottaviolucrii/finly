import 'package:flutter/material.dart';

/// The title of a screen's top bar, with a small "Empresa" tag in the company
/// workspace, so it is always clear which money is on screen. The tag takes
/// the bar's own colors (white on the blue bar).
class WorkspaceTitle extends StatelessWidget {
  final String text;
  final bool isBusiness;

  const WorkspaceTitle(this.text, {super.key, required this.isBusiness});

  @override
  Widget build(BuildContext context) {
    if (!isBusiness) return Text(text, overflow: TextOverflow.ellipsis);

    final color = DefaultTextStyle.of(context).style.color ?? Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'Empresa',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}
