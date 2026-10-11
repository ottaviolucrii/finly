import 'package:flutter/material.dart';

/// The four places of the app. The "+" in the middle of the bar is an action,
/// not a place.
enum FinlyTab { home, statement, plan, more }

/// The bar at the bottom of the app: Início, Extrato, a round "+" that adds a
/// transaction, Planejar and Mais.
class FinlyTabBar extends StatelessWidget {
  final FinlyTab current;
  final ValueChanged<FinlyTab> onSelect;

  /// Opens the form of a new transaction. Null disables the "+".
  final VoidCallback? onAdd;

  const FinlyTabBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _TabButton(
                  tab: FinlyTab.home,
                  label: 'Início',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  current: current,
                  onSelect: onSelect,
                ),
                _TabButton(
                  tab: FinlyTab.statement,
                  label: 'Extrato',
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  current: current,
                  onSelect: onSelect,
                ),
                Expanded(child: Center(child: _AddButton(onPressed: onAdd))),
                _TabButton(
                  tab: FinlyTab.plan,
                  label: 'Planejar',
                  icon: Icons.track_changes_outlined,
                  selectedIcon: Icons.track_changes,
                  current: current,
                  onSelect: onSelect,
                ),
                _TabButton(
                  tab: FinlyTab.more,
                  label: 'Mais',
                  icon: Icons.grid_view_outlined,
                  selectedIcon: Icons.grid_view_rounded,
                  current: current,
                  onSelect: onSelect,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final FinlyTab tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final FinlyTab current;
  final ValueChanged<FinlyTab> onSelect;

  const _TabButton({
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = tab == current;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: () => onSelect(tab),
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => onSelect(tab),
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Novo lançamento',
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: enabled ? scheme.primary : scheme.outline,
        shape: const CircleBorder(),
        elevation: enabled ? 4 : 0,
        shadowColor: scheme.primary.withValues(alpha: 0.5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add, color: scheme.onPrimary, size: 28),
          ),
        ),
      ),
    );
  }
}
