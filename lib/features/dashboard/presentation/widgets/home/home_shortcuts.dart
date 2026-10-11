import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// The four shortcuts of Início, on a white card that floats over the edge of
/// the band.
class HomeShortcuts extends StatelessWidget {
  final VoidCallback? onAdd;
  final VoidCallback? onTransfer;
  final VoidCallback onPayInvoice;
  final VoidCallback onForecast;

  const HomeShortcuts({
    super.key,
    required this.onAdd,
    required this.onTransfer,
    required this.onPayInvoice,
    required this.onForecast,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 6,
      shadowColor: AppColors.midnight.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(
          children: [
            _Shortcut(icon: Icons.add, label: 'Lançar', onTap: onAdd),
            _Shortcut(icon: Icons.swap_horiz, label: 'Transferir', onTap: onTransfer),
            _Shortcut(icon: Icons.credit_card, label: 'Pagar fatura', onTap: onPayInvoice),
            _Shortcut(icon: Icons.show_chart, label: 'Previsão', onTap: onForecast),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Shortcut({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: dark ? AppColors.blueTintDark : AppColors.blueTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: scheme.primary, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: onTap == null ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
