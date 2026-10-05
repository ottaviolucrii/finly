import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class SignInParams extends Equatable {
  final String email;
  final String password;

  const SignInParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignInUseCase implements UseCase<UserEntity, SignInParams> {
  final AuthRepository _repository;

  const SignInUseCase(this._repository);

  @override
  Future<Either<Failure, UserEntity>> call(SignInParams params) async {
    final email = params.email.trim();

    if (!Validators.isValidEmail(email)) {
      return const Left(ValidationFailure('invalid_email'));
    }
    // No strength rule here: older accounts may predate the password policy.
    if (params.password.isEmpty) {
      return const Left(ValidationFailure('password_required'));
    }

    return _repository.signIn(email: email, password: params.password);
  }
}