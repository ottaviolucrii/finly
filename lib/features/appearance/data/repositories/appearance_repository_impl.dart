import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/appearance/data/datasources/appearance_remote_data_source.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/domain/repositories/appearance_repository.dart';

class AppearanceRepositoryImpl implements AppearanceRepository {
  final AppearanceRemoteDataSource _remote;

  const AppearanceRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, AppearanceMode>> getMode() {
    return _guard<AppearanceMode>(() => _remote.getMode());
  }

  @override
  Future<Either<Failure, void>> saveMode(AppearanceMode mode) {
    return _guard<void>(() => _remote.saveMode(mode));
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error) are mapped to an unknown_error failure and logged.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}
