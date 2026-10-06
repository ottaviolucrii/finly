import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

/// The word the user must type to confirm. Case and surrounding spaces do not
/// matter.
const String deleteAccountConfirmationWord = 'EXCLUIR';

class DeleteAccountParams extends Equatable {
  final String password;

  /// What the user typed in the confirmation box.
  final String confirmation;

  const DeleteAccountParams({
    required this.password,
    required this.confirmation,
  });

  @override
  List<Object?> get props => [password, confirmation];
}

/// Erases the user and everything they own. There is no way back, so the
/// confirmation word is checked here and not only on the screen.
class DeleteAccountUseCase implements UseCase<void, DeleteAccountParams> {
  final AuthRepository _repository;

  const DeleteAccountUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(DeleteAccountParams params) async {
    if (params.password.isEmpty) {
      return const Left(ValidationFailure('password_required'));
    }
    if (params.confirmation.trim().toUpperCase() != deleteAccountConfirmationWord) {
      return const Left(ValidationFailure('confirmation_mismatch'));
    }
    return _repository.deleteAccount(password: params.password);
  }
}