import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';

class MonthlyFlowEntryModel extends MonthlyFlowEntry {
  const MonthlyFlowEntryModel({
    required super.month,
    required super.currency,
    required super.incomeCents,
    required super.expenseCents,
  });

  /// [map] is a row of the `monthly_flow` view.
  factory MonthlyFlowEntryModel.fromMap(Map<String, dynamic> map) {
    final parsed = DateTime.parse(map['month'] as String);
    return MonthlyFlowEntryModel(
      month: DateTime(parsed.year, parsed.month),
      currency: map['currency'] as String,
      incomeCents: (map['income_cents'] as num).toInt(),
      expenseCents: (map['expense_cents'] as num).toInt(),
    );
  }
}