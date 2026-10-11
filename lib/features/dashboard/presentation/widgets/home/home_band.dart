import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:flutter/material.dart';

/// The Finly shield, a small square image with a white background.
const finlyMarkAsset = 'assets/brand/finly_mark.png';

/// An amount, or dots when the person chose to hide the values.
String maskedMoney(Money money, {required bool hidden}) {
  return hidden ? '${Money.symbolFor(money.currency)} ••••••' : money.format();
}

/// The top of Início: the deep blue band of the brand with the logo, the
/// workspace, a button to hide the values, the avatar, the balance in accounts
/// and two small figures (what is expected, and what is in use on cards).
///
/// It leaves room at its bottom for the shortcuts, which float over its edge.
class HomeBand extends StatelessWidget {
  /// "Pessoal" or "Empresa".
  final String workspaceLabel;

  /// Opens the switch to the other workspace; null when there is none.
  final VoidCallback? onSwitchWorkspace;

  final bool hidden;
  final VoidCallback onToggleHidden;

  /// The first letter of the person's name, for the avatar.
  final String initial;
  final VoidCallback onProfile;

  /// Null while the balance is loading.
  final List<CurrencyBalance>? balances;
  final bool hasAccounts;

  /// The space left under the band for the shortcuts that overlap it.
  final double bottomSpace;

  const HomeBand({
    super.key,
    required this.workspaceLabel,
    required this.onSwitchWorkspace,
    required this.hidden,
    required this.onToggleHidden,
    required this.initial,
    required this.onProfile,
    required this.balances,
    required this.hasAccounts,
    this.bottomSpace = 72,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final list = balances;
    final main = (list == null || list.isEmpty) ? null : list.first;
    final others = (list == null || list.length < 2) ? const <CurrencyBalance>[] : list.sublist(1);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deepBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, top + 12, 20, bottomSpace),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  finlyMarkAsset,
                  width: 36,
                  height: 36,
                  semanticLabel: 'Finly',
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 36,
                    height: 36,
                    child: ColoredBox(
                      color: AppColors.white,
                      child: Icon(Icons.shield_outlined, color: AppColors.techBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _WorkspaceButton(label: workspaceLabel, onTap: onSwitchWorkspace),
              ),
              const Spacer(),
              _BandIconButton(
                icon: hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                tooltip: hidden ? 'Mostrar valores' : 'Esconder valores',
                onPressed: onToggleHidden,
              ),
              const SizedBox(width: 8),
              _Avatar(initial: initial, onTap: onProfile),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Saldo em contas',
            style: TextStyle(fontSize: 14, color: AppColors.onBand),
          ),
          const SizedBox(height: 6),
          Text(
            main == null
                ? (list == null ? '—' : maskedMoney(const Money(0, 'BRL'), hidden: hidden))
                : maskedMoney(main.posted, hidden: hidden),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 36,
              height: 1.15,
              letterSpacing: -0.6,
              color: main != null && main.postedCents < 0 && !hidden
                  ? AppColors.goldOnBand
                  : AppColors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (list != null && !hasAccounts)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Nenhuma conta ainda. Crie a primeira em Mais › Contas.',
                style: TextStyle(fontSize: 13, color: AppColors.onBand),
              ),
            ),
          for (final other in others)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                maskedMoney(other.posted, hidden: hidden),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.white),
              ),
            ),
          if (main != null && (main.hasPendingEffect || main.cardDebtCents > 0)) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (main.hasPendingEffect)
                  _BandChip(label: 'Previsto', value: maskedMoney(main.projected, hidden: hidden)),
                if (main.cardDebtCents > 0)
                  _BandChip(
                    label: 'Cartões',
                    value: maskedMoney(main.cardDebt, hidden: hidden),
                    valueColor: AppColors.goldOnBand,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _WorkspaceButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: onTap == null ? 'Workspace: $label' : 'Workspace: $label. Trocar de workspace',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: AppColors.white,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.onBand, size: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BandIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _BandIconButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.white, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final VoidCallback onTap;

  const _Avatar({required this.initial, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Sua conta e mais opções',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.gold,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.midnight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _BandChip({required this.label, required this.value, this.valueColor = AppColors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onBand)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ],
      ),
    );
  }
}
