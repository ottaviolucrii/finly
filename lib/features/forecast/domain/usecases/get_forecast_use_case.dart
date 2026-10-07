import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/domain/forecast_rules.dart';
import 'package:finly/features/forecast/domain/repositories/forecast_repository.dart';

class GetForecastParams extends Equatable {
  final String workspaceId;

  /// "Now"; any time of the day.
  final DateTime today;

  const GetForecastParams({required this.workspaceId, required this.today});

  @override
  List<Object?> get props => [workspaceId, today];
}

/// The balance forecast of a workspace for the next [forecastMaxDays] days,
/// one per currency. The screen cuts it to 30 or 60 days when asked.
class GetForecastUseCase implements UseCase<List<Forecast>, GetForecastParams> {
  final ForecastRepository _repository;

  const GetForecastUseCase(this._repository);

  @override
  Future<Either<Failure, List<Forecast>>> call(GetForecastParams params) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final today = dateOnly(params.today);
    // The end is excluded, so one day past the last day of the forecast.
    final until = DateTime(today.year, today.month, today.day + forecastMaxDays + 1);

    final result = await _repository.getInputs(workspaceId, until: until);
    return result.map((inputs) => buildForecasts(inputs, today: today));
  }
}
