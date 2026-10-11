import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:flutter/material.dart';

/// The accounts Início shows: every account but the credit cards (they have
/// their own place).
List<AccountEntity> homeAccounts(List<AccountEntity> accounts) =>
    [for (final account in accounts) if (account.type != AccountType.creditCard) account];

/// "Minhas contas": a row of small cards, one per account, with its balance,
/// and a last card to create one. Swipe it sideways when there are many.
class HomeAccountsRow extends StatelessWidget {
  /// Null while loading.
  final List<AccountEntity>? accounts;
  final bool hidden;
  final ValueChanged<AccountEntity> onOpenAccount;
  final VoidCallback onSeeAll;
  final VoidCallback onNewAccount;

  const HomeAccountsRow({
    super.key,
    required this.accounts,
    required this.hidden,
    required this.onOpenAccount,
    required this.onSeeAll,
    required this.onNewAccount,
  });

  static const cardHeight = 112.0;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = accounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                container: true,
                header: true,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('Minhas contas', style: text.titleLarge?.copyWith(fontSize: 17)),
                ),
              ),
            ),
            if (list != null && list.isNotEmpty) TextButton(onPressed: onSeeAll, child: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: cardHeight,
          child: list == null
              ? const Center(child: CircularProgressIndicator())
              : list.isEmpty
                  ? NewAccountTile(onTap: onNewAccount, label: 'Criar a primeira conta')
                  : list.length == 1
                      ? Row(
                          children: [
                            Expanded(
                              child: AccountMiniCard(
                                account: list.single,
                                hidden: hidden,
                                subtitle: '${accountTypeLabel(list.single.type)} · a sua única conta',
                                onTap: () => onOpenAccount(list.single),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(width: 120, child: NewAccountTile(onTap: onNewAccount)),
                          ],
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          itemCount: list.length + 1,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, i) => i < list.length
                              ? SizedBox(
                                  width: 156,
                                  child: AccountMiniCard(
                                    account: list[i],
                                    hidden: hidden,
                                    onTap: () => onOpenAccount(list[i]),
                                  ),
                                )
                              : SizedBox(width: 120, child: NewAccountTile(onTap: onNewAccount)),
                        ),
        ),
      ],
    );
  }
}

/// One account: its icon, its name, its type and its balance (red when below
/// zero).
class AccountMiniCard extends StatelessWidget {
  final AccountEntity account;
  final bool hidden;
  final VoidCallback onTap;

  /// Replaces the type under the name.
  final String? subtitle;

  const AccountMiniCard({
    super.key,
    required this.account,
    required this.hidden,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final balance = maskedMoney(account.postedBalance, hidden: hidden);
    final negative = account.postedBalanceCents < 0 && !hidden;

    return Semantics(
      button: true,
      label: 'Conta ${account.name}, saldo $balance. Abrir o extrato desta conta',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dark ? AppColors.blueTintDark : AppColors.blueTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(accountTypeIcon(account.type), size: 17, color: scheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  subtitle ?? accountTypeLabel(account.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    balance,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: negative ? scheme.error : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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

/// A dashed place to create an account.
class NewAccountTile extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const NewAccountTile({super.key, required this.onTap, this.label = 'Nova conta'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: CustomPaint(
        painter: _Dashes(color: scheme.outline),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: scheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dashes extends CustomPainter {
  final Color color;

  const _Dashes({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 8), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_Dashes oldDelegate) => oldDelegate.color != color;
}
