import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetMonthTotalsParams extends Equatable {
  final String workspaceId;

  /// Any day of the month.
  final DateTime month;

  const GetMonthTotalsParams({required this.workspaceId, required this.month});

  @override
  List<Object?> get props => [workspaceId, month];
}

/// What came in and what went out in one month, per currency, counting only
/// what already happened (posted). The database adds them up, so the totals
/// are right however many transactions the month has.
class GetMonthTotalsUseCase
    implements UseCase<List<MonthlyFlowEntry>, GetMonthTotalsParams> {
  final DashboardRepository _dashboard;

  const GetMonthTotalsUseCase(this._dashboard);

  @override
  Future<Either<Failure, List<MonthlyFlowEntry>>> call(
    GetMonthTotalsParams params,
  ) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final month = DateTime(params.month.year, params.month.month);
    final next = DateTime(month.year, month.month + 1);
    final result = await _dashboard.getMonthlyFlow(
      params.workspaceId,
      from: month,
      to: next,
    );

    return result.map(
      (entries) => [
        for (final entry in entries)
          if (entry.month.year == month.year && entry.month.month == month.month)
            entry,
      ],
    );
  }
}
