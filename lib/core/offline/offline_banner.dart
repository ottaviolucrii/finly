import 'package:finly/core/offline/offline_status.dart';
import 'package:flutter/material.dart';

/// "hoje 14:32" or "07/10 14:32": when a copy was made, for the banner.
String cachedAtText(DateTime savedAt, DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  final time = '${two(savedAt.hour)}:${two(savedAt.minute)}';

  final sameDay = savedAt.year == now.year && savedAt.month == now.month && savedAt.day == now.day;
  return sameDay ? 'hoje $time' : '${two(savedAt.day)}/${two(savedAt.month)} $time';
}

/// A strip above the app that says when it shows saved copies, and offers to
/// refresh when the internet comes back.
class OfflineBanner extends StatelessWidget {
  final OfflineStatus status;
  final Widget child;

  /// "Now", to say "hoje"; tests pass a fixed date.
  final DateTime Function()? clock;

  const OfflineBanner({super.key, required this.status, required this.child, this.clock});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: status,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final since = status.cachedSince;
        final now = (clock ?? DateTime.now)();

        Widget? bar;
        if (status.isOffline) {
          final text = since == null
              ? 'Sem conexão ou conexão lenta.'
              : 'Sem conexão ou conexão lenta: mostrando dados salvos de ${cachedAtText(since, now)}.';
          bar = _Bar(
            color: scheme.errorContainer,
            textColor: scheme.onErrorContainer,
            icon: Icons.cloud_off_outlined,
            text: text,
          );
        } else if (status.isBackOnline) {
          bar = _Bar(
            color: scheme.primaryContainer,
            textColor: scheme.onPrimaryContainer,
            icon: Icons.cloud_done_outlined,
            text: 'A internet voltou.',
            actionLabel: 'Atualizar',
            onAction: status.refresh,
          );
        }

        // The same widgets in the same places whether the bar is shown or not:
        // if the child moved, Flutter would build the navigator below it again
        // and the person would be taken back to the first screen.
        return Column(
          children: [
            bar ?? const SizedBox.shrink(),
            Expanded(
              // The bar sits under the status bar, so the pages below it must
              // not leave that space empty again.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: bar != null,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Bar({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: textColor, visualDensity: VisualDensity.compact),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
