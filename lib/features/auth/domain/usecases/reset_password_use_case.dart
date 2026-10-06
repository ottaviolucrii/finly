import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

class ResetPasswordParams extends Equatable {
  final String email;

  /// The one-time code from the e-mail.
  final String code;
  final String newPassword;

  const ResetPasswordParams({
    required this.email,
    required this.code,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [email, code, newPassword];
}

/// Sets a new password with the one-time code sent by e-mail.
class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  final AuthRepository _repository;

  const ResetPasswordUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) async {
    final email = params.email.trim();
    if (!Validators.isValidEmail(email)) {
      return const Left(ValidationFailure('invalid_email'));
    }
    // 6 to 10 digits: the length is a Supabase setting.
    final code = params.code.trim();
    if (!RegExp(r'^\d{6,10}$').hasMatch(code)) {
      return const Left(ValidationFailure('invalid_code'));
    }
    // A bad password is refused here, before the code is spent.
    if (!Validators.isValidPassword(params.newPassword)) {
      return const Left(ValidationFailure('weak_password'));
    }

    return _repository.resetPassword(
      email: email,
      code: code,
      newPassword: params.newPassword,
    );
  }
}