import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/forecast/data/datasources/forecast_remote_data_source.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/domain/repositories/forecast_repository.dart';

class ForecastRepositoryImpl implements ForecastRepository {
  final ForecastRemoteDataSource _remote;

  const ForecastRepositoryImpl(this._remote);

  /// Exceptions become Left(Failure). Programming errors (Error) are mapped to
  /// an unknown_error failure and logged.
  @override
  Future<Either<Failure, ForecastInputs>> getInputs(
    String workspaceId, {
    required DateTime until,
  }) async {
    try {
      return Right<Failure, ForecastInputs>(
        await _remote.getInputs(workspaceId, until: until),
      );
    } catch (e) {
      return Left<Failure, ForecastInputs>(ErrorMapper.toFailure(e));
    }
  }
}
