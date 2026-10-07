import 'package:finly/core/money/money.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:flutter/material.dart';

/// The list of accounts a transaction can be moved to. [onSelected] is called
/// with the account the user taps; the caller closes the sheet.
class MoveAccountSheet extends StatelessWidget {
  final List<AccountEntity> targets;
  final String currency;
  final ValueChanged<AccountEntity> onSelected;

  const MoveAccountSheet({
    super.key,
    required this.targets,
    required this.currency,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mover para qual conta?',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Só contas em $currency do mesmo workspace. Alterações não '
              'salvas nesta tela serão descartadas.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final account in targets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  account.type == AccountType.creditCard
                      ? Icons.credit_card
                      : Icons.account_balance_wallet_outlined,
                ),
                title: Text(account.name),
                subtitle: Text(
                  account.type == AccountType.creditCard
                      ? 'Cartão de crédito: entra na fatura da data'
                      : 'Saldo ${Money(account.postedBalanceCents, account.currency).format()}',
                ),
                onTap: () => onSelected(account),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
