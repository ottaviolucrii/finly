import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';

abstract class LockRepository {
  /// The lock settings of the signed-in user.
  Future<Either<Failure, LockSettings>> getSettings();

  Future<Either<Failure, void>> saveSettings(LockSettings settings);

  /// Checks the account password again (the fallback to unlock the app). A
  /// wrong password is an AuthFailure('invalid_credentials').
  Future<Either<Failure, void>> verifyPassword(String password);
}