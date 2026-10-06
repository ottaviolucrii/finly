import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';

/// A bottom sheet to pick the type, status, account, category and period. Pops
/// with the new [TransactionFilter] when the user taps "Aplicar". The search
/// text of [initial] is kept as it is.
class TransactionFilterSheet extends StatefulWidget {
  final TransactionFilter initial;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const TransactionFilterSheet({
    super.key,
    required this.initial,
    required this.accounts,
    required this.categories,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionType? _type = widget.initial.type;
  late TransactionStatus? _status = widget.initial.status;
  late String? _accountId = widget.initial.accountId;
  late String? _categoryId = widget.initial.categoryId;
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;

  void _clear() => setState(() {
        _type = null;
        _status = null;
        _accountId = null;
        _categoryId = null;
        _from = null;
        _to = null;
      });

  void _apply() {
    var from = _from;
    var to = _to;
    // "De" after "Até": swap them instead of showing an empty list.
    if (from != null && to != null && from.isAfter(to)) {
      final swap = from;
      from = to;
      to = swap;
    }

    Navigator.of(context).pop(
      TransactionFilter(
        search: widget.initial.search,
        type: _type,
        status: _status,
        accountId: _accountId,
        categoryId: _categoryId,
        from: from,
        to: to,
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  void _setPeriod(DateTime from, DateTime to) => setState(() {
        _from = from;
        _to = to;
      });

  Widget _section(String title, List<Widget> chips) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: chips),
        ],
      ),
    );
  }

  Widget _dateChip(
    String label,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return InputChip(
      avatar: const Icon(Icons.event, size: 18),
      label: Text(value == null ? label : '$label ${formatDateBr(value)}'),
      onPressed: () async {
        final picked = await _pickDate(value);
        if (picked != null) onChanged(picked);
      },
      onDeleted: value == null ? null : () => onChanged(null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtros', style: text.headlineSmall, textAlign: TextAlign.center),
            _section('Período', [
              ActionChip(
                label: const Text('Este mês'),
                onPressed: () => _setPeriod(
                  DateTime(today.year, today.month, 1),
                  DateTime(today.year, today.month + 1, 0),
                ),
              ),
              ActionChip(
                label: const Text('Mês passado'),
                onPressed: () => _setPeriod(
                  DateTime(today.year, today.month - 1, 1),
                  DateTime(today.year, today.month, 0),
                ),
              ),
              ActionChip(
                label: const Text('Últimos 30 dias'),
                onPressed: () => _setPeriod(
                  today.subtract(const Duration(days: 29)),
                  today,
                ),
              ),
              _dateChip('De', _from, (value) => setState(() => _from = value)),
              _dateChip('Até', _to, (value) => setState(() => _to = value)),
            ]),
            _section('Tipo', [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              ChoiceChip(
                label: const Text('Entradas'),
                selected: _type == TransactionType.income,
                onSelected: (_) => setState(() => _type = TransactionType.income),
              ),
              ChoiceChip(
                label: const Text('Saídas'),
                selected: _type == TransactionType.expense,
                onSelected: (_) => setState(() => _type = TransactionType.expense),
              ),
            ]),
            _section('Status', [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _status == null,
                onSelected: (_) => setState(() => _status = null),
              ),
              ChoiceChip(
                label: const Text('Pendentes'),
                selected: _status == TransactionStatus.pending,
                onSelected: (_) =>
                    setState(() => _status = TransactionStatus.pending),
              ),
              ChoiceChip(
                label: const Text('Confirmadas'),
                selected: _status == TransactionStatus.posted,
                onSelected: (_) =>
                    setState(() => _status = TransactionStatus.posted),
              ),
            ]),
            if (widget.accounts.isNotEmpty)
              _section('Conta', [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _accountId == null,
                  onSelected: (_) => setState(() => _accountId = null),
                ),
                for (final account in widget.accounts)
                  ChoiceChip(
                    label: Text(account.name),
                    selected: _accountId == account.id,
                    onSelected: (_) => setState(() => _accountId = account.id),
                  ),
              ]),
            if (widget.categories.isNotEmpty)
              _section('Categoria', [
                ChoiceChip(
                  label: const Text('Todas'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
                for (final category in widget.categories)
                  ChoiceChip(
                    label: Text(
                      category.isArchived
                          ? '${category.name} (arquivada)'
                          : category.name,
                    ),
                    selected: _categoryId == category.id,
                    onSelected: (_) => setState(() => _categoryId = category.id),
                  ),
              ]),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _clear,
                    child: const Text('Limpar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}