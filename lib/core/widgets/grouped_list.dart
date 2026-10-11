import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// One row of a [GroupedSection].
class GroupedItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// A destructive row (like "Sair"): red, with no arrow.
  final bool danger;

  const GroupedItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });
}

/// A round tinted badge with an icon, used at the start of rows.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final bool danger;
  final double size;

  const IconBadge({super.key, required this.icon, this.danger = false, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color background;
    final Color foreground;
    if (danger) {
      background = scheme.error.withValues(alpha: 0.12);
      foreground = scheme.error;
    } else {
      background = dark ? AppColors.blueTintDark : AppColors.blueTint;
      foreground = scheme.primary;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: size / 2),
    );
  }
}

/// A small label above a group of rows ("DINHEIRO", "ANÁLISES").
class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A card with rows, like a settings list: an icon badge, a title, an optional
/// subtitle and an arrow. The rows are separated by thin lines.
class GroupedSection extends StatelessWidget {
  final String? label;
  final List<GroupedItem> items;

  const GroupedSection({super.key, this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) SectionLabel(label!),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(indent: 72),
                ListTile(
                  minVerticalPadding: 12,
                  leading: IconBadge(icon: items[i].icon, danger: items[i].danger),
                  title: Text(
                    items[i].title,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: items[i].danger ? scheme.error : null,
                    ),
                  ),
                  subtitle: items[i].subtitle == null
                      ? null
                      : Text(
                          items[i].subtitle!,
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                  trailing: items[i].danger
                      ? null
                      : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  onTap: items[i].onTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The light top of a tab: a small blue line ("OUTUBRO DE 2026") over a big
/// title ("Planejar").
class TabHeader extends StatelessWidget {
  final String kicker;
  final String title;

  const TabHeader({super.key, required this.kicker, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        // Its own node, so a screen reader announces the title as the
        // heading, not the small line above it too.
        Semantics(
          container: true,
          header: true,
          child: Text(title, style: text.headlineMedium),
        ),
      ],
    );
  }
}
