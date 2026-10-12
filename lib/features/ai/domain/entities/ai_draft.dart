import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// A transaction the AI read from a sentence. It only fills in the "+" sheet:
/// the person checks it and saves. Any field may be missing (null).
class AiDraft extends Equatable {
  final TransactionType type;
  final int? amountCents;
  final String description;
  final String? categoryId;
  final String? accountId;
  final DateTime date;
  final bool pending;

  const AiDraft({
    required this.type,
    required this.amountCents,
    required this.description,
    required this.categoryId,
    required this.accountId,
    required this.date,
    required this.pending,
  });

  /// From the answer of the function. [fallbackDate] is used when the date
  /// is missing or unreadable.
  factory AiDraft.fromJson(Map<String, dynamic> json, {required DateTime fallbackDate}) {
    final amount = json['amountCents'];
    final date = DateTime.tryParse('${json['date']}');
    return AiDraft(
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      amountCents: amount is int && amount > 0 ? amount : null,
      description: json['description'] is String ? (json['description'] as String).trim() : '',
      categoryId: json['categoryId'] is String ? json['categoryId'] as String : null,
      accountId: json['accountId'] is String ? json['accountId'] as String : null,
      date: date == null ? fallbackDate : DateTime(date.year, date.month, date.day),
      pending: json['pending'] == true,
    );
  }

  @override
  List<Object?> get props => [type, amountCents, description, categoryId, accountId, date, pending];
}
