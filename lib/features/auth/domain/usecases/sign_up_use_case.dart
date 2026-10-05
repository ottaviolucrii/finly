import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class SignUpParams extends Equatable {
  final String fullName;
  final String email;
  final String password;
  final bool acceptedTerms;

  const SignUpParams({
    required this.fullName,
    required this.email,
    required this.password,
    required this.acceptedTerms,
  });

  @override
  List<Object?> get props => [fullName, email, password, acceptedTerms];
}

class SignUpUseCase implements UseCase<SignUpResult, SignUpParams> {
  final AuthRepository _repository;

  const SignUpUseCase(this._repository);

  @override
  Future<Either<Failure, SignUpResult>> call(SignUpParams params) async {
    final fullName = params.fullName.trim();
    final email = params.email.trim();

    if (!Validators.isValidFullName(fullName)) {
      return const Left(ValidationFailure('invalid_full_name'));
    }
    if (!Validators.isValidEmail(email)) {
      return const Left(ValidationFailure('invalid_email'));
    }
    if (!Validators.isValidPassword(params.password)) {
      return const Left(ValidationFailure('weak_password'));
    }
    if (!params.acceptedTerms) {
      return const Left(ValidationFailure('terms_not_accepted'));
    }

    return _repository.signUp(
      email: email,
      password: params.password,
      fullName: fullName,
    );
  }
}