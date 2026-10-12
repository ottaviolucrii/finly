import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/statement_filters.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';

/// The chips under the band: Tudo, Entradas, Saídas, Pendentes.
class QuickFilterChips extends StatelessWidget {
  /// The chip that matches the filter; null when none does.
  final QuickFilter? selected;
  final ValueChanged<QuickFilter> onSelected;

  const QuickFilterChips({super.key, required this.selected, required this.onSelected});

  static const _labels = {
    QuickFilter.all: 'Tudo',
    QuickFilter.income: 'Entradas',
    QuickFilter.expense: 'Saídas',
    QuickFilter.pending: 'Pendentes',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final quick in QuickFilter.values) ...[
            if (quick != QuickFilter.all) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(_labels[quick]!),
              selected: quick == selected,
              showCheckmark: false,
              selectedColor: dark ? AppColors.textOnDark : AppColors.midnight,
              labelStyle: TextStyle(
                fontWeight: quick == selected ? FontWeight.w600 : FontWeight.w500,
                color: quick == selected
                    ? (dark ? AppColors.midnight : AppColors.white)
                    : scheme.onSurface,
              ),
              onSelected: (_) => onSelected(quick),
            ),
          ],
        ],
      ),
    );
  }
}

/// One day of the statement: a small label in capitals ("HOJE") over a white
/// card with the transactions of that day.
class StatementDayGroup extends StatelessWidget {
  final String label;
  final List<Widget> rows;

  const StatementDayGroup({super.key, required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(indent: 72),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// What the subtitle of a row says: the category and the account.
String statementSubtitle(TransactionEntity transaction, CategoryEntity? category, AccountEntity? account) {
  final what = category?.name ??
      (transaction.isTransferLeg
          ? 'Transferência'
          : (transaction.categoryId != null ? 'Categoria arquivada' : 'Sem categoria'));
  return '$what · ${account?.name ?? 'Conta'}';
}

/// One transaction: the category badge, the description, the category and
/// the account, the amount, and for a pending one the tag and "Confirmar".
/// Swipe left or use the menu to delete.
class StatementRow extends StatelessWidget {
  final TransactionEntity transaction;
  final AccountEntity? account;
  final CategoryEntity? category;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  /// Asks before deleting (used for transfers). Null means no question.
  final Future<bool> Function()? confirmDelete;

  const StatementRow({
    super.key,
    required this.transaction,
    required this.account,
    required this.category,
    required this.onTap,
    required this.onConfirm,
    required this.onDelete,
    this.confirmDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final tone = category != null ? categoryColor(category!.colorHex) : scheme.onSurfaceVariant;
    final icon = category != null ? categoryIcon(category!.icon) : transactionTypeIcon(transaction.type);
    final credit = transaction.type.isCredit;
    final amountColor = credit ? (dark ? const Color(0xFF6FD39B) : AppColors.positive) : scheme.onSurface;

    return Dismissible(
      key: ValueKey('statement-${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: confirmDelete == null ? null : (_) => confirmDelete!.call(),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: dark ? 0.22 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      statementSubtitle(transaction, category, account),
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        transactionAmountText(transaction),
                        maxLines: 1,
                        style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: amountColor),
                      ),
                    ),
                  ),
                  if (transaction.isPending) ...[
                    const SizedBox(height: 4),
                    Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.gold.withValues(alpha: 0.18) : AppColors.goldTint,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Pendente',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dark ? AppColors.goldOnBand : AppColors.goldOnLight,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onConfirm,
                      child: const Text('Confirmar'),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}
