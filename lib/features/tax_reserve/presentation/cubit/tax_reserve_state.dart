import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';

enum TaxReserveStatus { loading, loaded, failure }

class TaxReserveState extends Equatable {
  final TaxReserveStatus status;

  /// First day of the month on screen.
  final DateTime month;

  /// First day of the current month: the screen cannot go past it.
  final DateTime currentMonth;

  /// What was read. It stays on screen while the next month loads.
  final TaxReserveData? data;
  final Failure? failure;

  /// True while a new percentage is being saved.
  final bool saving;

  /// Set when saving the percentage failed; cleared by the next save.
  final Failure? saveFailure;

  const TaxReserveState({
    required this.month,
    required this.currentMonth,
    this.status = TaxReserveStatus.loading,
    this.data,
    this.failure,
    this.saving = false,
    this.saveFailure,
  });

  bool get canGoNext => month.isBefore(currentMonth);

  @override
  List<Object?> get props => [
        status,
        month,
        currentMonth,
        data,
        failure,
        saving,
        saveFailure,
      ];
}
