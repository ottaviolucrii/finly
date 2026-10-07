import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';

abstract class ForecastRepository {
  /// What the forecast of [workspaceId] starts from: the balances today, the
  /// pending bills and incomes, the active recurring items and the unpaid card
  /// invoices. Movements dated before [until] (excluded) are the ones needed.
  Future<Either<Failure, ForecastInputs>> getInputs(
    String workspaceId, {
    required DateTime until,
  });
}
