import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_state.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/tax_reserve_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A hex colour of the database ("#RRGGBB") as a colour, or grey when it is not
/// one.
Color taxCategoryColor(String hex) {
  final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
  if (match == null) return Colors.grey;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// "Categorias de imposto": the expense categories, each with a switch that
/// says whether it counts in "Impostos do mês". It uses the
/// [TaxCategoriesCubit] and the [TaxReserveCubit] above it, and reads the
/// numbers of the screen again when a switch was saved.
class TaxCategoriesCard extends StatelessWidget {
  const TaxCategoriesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaxCategoriesCubit, TaxCategoriesState>(
      listenWhen: (previous, current) =>
          current.changes != previous.changes ||
          (current.saveFailure != null && current.saveFailure != previous.saveFailure),
      listener: (context, state) {
        final failure = state.saveFailure;
        if (failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(taxReserveFailureMessage(failure))));
        } else {
          // A change was saved: the taxes of the month may be different now.
          context.read<TaxReserveCubit>().reload();
        }
      },
      builder: (context, state) {
        final text = Theme.of(context).textTheme;
        final marked = state.markedNames;

        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Categorias de imposto'),
            subtitle: Text(
              state.status == TaxCategoriesStatus.loaded
                  ? (marked.isEmpty ? 'Nenhuma marcada' : marked.join(', '))
                  : 'Quais despesas contam como imposto',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  'Marque as categorias de despesa que são impostos. Elas entram em '
                  '"Impostos do mês".',
                  style: text.bodySmall,
                ),
              ),
              ..._rows(context, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _rows(BuildContext context, TaxCategoriesState state) {
    final cubit = context.read<TaxCategoriesCubit>();

    if (state.categories.isEmpty) {
      if (state.status == TaxCategoriesStatus.failure) {
        return [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  taxReserveFailureMessage(state.failure!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: cubit.reload, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        ];
      }
      if (state.status == TaxCategoriesStatus.loading) {
        return const [
          Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
        ];
      }
      return const [
        Padding(
          padding: EdgeInsets.all(8),
          child: Text('Este workspace não tem categorias de despesa.'),
        ),
      ];
    }

    return [
      for (final category in state.categories) _row(context, state, category),
    ];
  }

  Widget _row(BuildContext context, TaxCategoriesState state, TaxCategory category) {
    final cubit = context.read<TaxCategoriesCubit>();

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: CircleAvatar(
        radius: 10,
        backgroundColor: taxCategoryColor(category.colorHex),
      ),
      title: Text(category.name),
      value: category.isTax,
      onChanged: state.savingId == null
          ? (value) => cubit.setTax(category.id, isTax: value)
          : null,
    );
  }
}
