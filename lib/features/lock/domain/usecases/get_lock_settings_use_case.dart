import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/repositories/lock_repository.dart';

class GetLockSettingsUseCase implements UseCase<LockSettings, NoParams> {
  final LockRepository _repository;

  const GetLockSettingsUseCase(this._repository);

  @override
  Future<Either<Failure, LockSettings>> call(NoParams params) {
    return _repository.getSettings();
  }
}