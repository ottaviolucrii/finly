import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

/// Restores the stored session when the app starts.
/// Right: the user, or null when nobody is signed in.
class GetCurrentUserUseCase implements UseCase<UserEntity?, NoParams> {
  final AuthRepository _repository;

  const GetCurrentUserUseCase(this._repository);

  @override
  Future<Either<Failure, UserEntity?>> call(NoParams params) {
    return _repository.getCurrentUser();
  }
}