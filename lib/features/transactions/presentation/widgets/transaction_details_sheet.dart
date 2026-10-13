import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';

/// What the person chose in the details of a transaction.
enum TransactionAction { edit, delete, confirm, receipt }

/// Opens the details of [transaction] in a sheet: everything in full (no
/// text cut), and what can be done with it. Returns the chosen action, or
/// null when the sheet was closed.
Future<TransactionAction?> showTransactionDetails(
  BuildContext context, {
  required TransactionEntity transaction,
  AccountEntity? account,
  CategoryEntity? category,
}) {
  return showModalBottomSheet<TransactionAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TransactionDetails(transaction: transaction, account: account, category: category),
  );
}

/// The content of the details sheet.
class TransactionDetails extends StatelessWidget {
  final TransactionEntity transaction;
  final AccountEntity? account;
  final CategoryEntity? category;

  const TransactionDetails({super.key, required this.transaction, this.account, this.category});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final category = this.category;
    final transfer = transaction.isTransferLeg;
    final tone = category != null ? categoryColor(category.colorHex) : scheme.onSurfaceVariant;
    final icon = category != null ? categoryIcon(category.icon) : transactionTypeIcon(transaction.type);
    final credit = transaction.type.isCredit;
    final amountColor = credit ? (dark ? const Color(0xFF6FD39B) : AppColors.positive) : scheme.onSurface;
    final at = transaction.occurredAt;
    final time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    void choose(TransactionAction action) => Navigator.of(context).pop(action);

    Widget line(IconData icon, String label, String value, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: Text(label, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              Expanded(
                child: Text(
                  value,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
                ),
              ),
            ],
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: dark ? 0.22 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tone, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  container: true,
                  header: true,
                  child: Text(transaction.description, style: text.titleLarge?.copyWith(fontSize: 19)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            transactionAmountText(transaction),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 32,
              letterSpacing: -0.5,
              color: amountColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  line(
                    Icons.sell_outlined,
                    'Categoria',
                    transfer ? 'Transferência' : (category?.name ?? 'Sem categoria'),
                  ),
                  line(Icons.account_balance_wallet_outlined, 'Conta', account?.name ?? 'Conta'),
                  line(Icons.event, 'Data', '${formatDateBr(at)} às $time'),
                  line(
                    Icons.receipt_long_outlined,
                    'Comprovante',
                    transaction.hasReceipt ? 'Anexado' : 'Nenhum',
                  ),
                  line(
                    transaction.isPending ? Icons.schedule : Icons.check_circle_outline,
                    'Situação',
                    transaction.isPending ? 'Pendente: entra no previsto, não no saldo' : 'Confirmada',
                    valueColor: transaction.isPending ? (dark ? AppColors.goldOnBand : AppColors.goldOnLight) : null,
                  ),
                ],
              ),
            ),
          ),
          if (transfer) ...[
            const SizedBox(height: 12),
            Text(
              'Transferências não podem ser editadas: para mudar, exclua e crie outra.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: Icon(transaction.hasReceipt ? Icons.image_outlined : Icons.add_a_photo_outlined),
            label: Text(transaction.hasReceipt ? 'Ver comprovante' : 'Anexar comprovante'),
            onPressed: () => choose(TransactionAction.receipt),
          ),
          const SizedBox(height: 12),
          if (transaction.isPending) ...[
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
              onPressed: () => choose(TransactionAction.confirm),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (!transfer) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                    onPressed: () => choose(TransactionAction.edit),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                  onPressed: () => choose(TransactionAction.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
