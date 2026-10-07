import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/repositories/lock_repository.dart';

/// Saves the lock settings. Only the times the screen offers are accepted.
class SaveLockSettingsUseCase implements UseCase<void, LockSettings> {
  final LockRepository _repository;

  const SaveLockSettingsUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(LockSettings settings) async {
    if (!lockTimeoutOptions.contains(settings.timeoutSeconds)) {
      return const Left(ValidationFailure('invalid_timeout'));
    }
    return _repository.saveSettings(settings);
  }
}