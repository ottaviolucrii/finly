import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class ChangePasswordParams extends Equatable {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordParams({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class ChangePasswordUseCase implements UseCase<void, ChangePasswordParams> {
  final AuthRepository _repository;

  const ChangePasswordUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ChangePasswordParams params) async {
    if (params.currentPassword.isEmpty) {
      return const Left(ValidationFailure('password_required'));
    }
    // Same rule as sign-up (SRS FR-A01).
    if (!Validators.isValidPassword(params.newPassword)) {
      return const Left(ValidationFailure('weak_password'));
    }
    if (params.newPassword == params.currentPassword) {
      return const Left(ValidationFailure('same_password'));
    }

    return _repository.changePassword(
      currentPassword: params.currentPassword,
      newPassword: params.newPassword,
    );
  }
}