import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/lock/data/datasources/lock_remote_data_source.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/repositories/lock_repository.dart';

class LockRepositoryImpl implements LockRepository {
  final LockRemoteDataSource _remote;

  const LockRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, LockSettings>> getSettings() {
    return _guard<LockSettings>(() => _remote.getSettings());
  }

  @override
  Future<Either<Failure, void>> saveSettings(LockSettings settings) {
    return _guard<void>(() => _remote.saveSettings(settings));
  }

  @override
  Future<Either<Failure, void>> verifyPassword(String password) {
    return _guard<void>(() => _remote.verifyPassword(password));
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