import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/change_password_use_case.dart';
import 'package:finly/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  group('ChangePasswordUseCase', () {
    void verifyNotCalled() {
      verifyNever(() => repository.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ));
    }

    test('requires the current password', () async {
      final result = await ChangePasswordUseCase(repository)(
        const ChangePasswordParams(currentPassword: '', newPassword: 'novaSenha1'),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('password_required')),
      );
      verifyNotCalled();
    });

    test('rejects a weak new password', () async {
      final useCase = ChangePasswordUseCase(repository);

      for (final weak in ['curta1', 'somenteletras', '12345678']) {
        final result = await useCase(
          ChangePasswordParams(currentPassword: 'senhaAtual1', newPassword: weak),
        );
        expect(
          result,
          const Left<Failure, void>(ValidationFailure('weak_password')),
          reason: weak,
        );
      }
      verifyNotCalled();
    });

    test('rejects a new password equal to the current one', () async {
      final result = await ChangePasswordUseCase(repository)(
        const ChangePasswordParams(
          currentPassword: 'senhaAtual1',
          newPassword: 'senhaAtual1',
        ),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('same_password')),
      );
      verifyNotCalled();
    });

    test('forwards a valid change to the repository', () async {
      when(() => repository.changePassword(
            currentPassword: 'senhaAtual1',
            newPassword: 'novaSenha2',
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await ChangePasswordUseCase(repository)(
        const ChangePasswordParams(
          currentPassword: 'senhaAtual1',
          newPassword: 'novaSenha2',
        ),
      );

      expect(result.isRight(), isTrue);
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          )).thenAnswer(
        (_) async =>
            const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );

      final result = await ChangePasswordUseCase(repository)(
        const ChangePasswordParams(
          currentPassword: 'errada123',
          newPassword: 'novaSenha2',
        ),
      );

      expect(
        result,
        const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
    });
  });

  group('DeleteAccountUseCase', () {
    test('requires the password', () async {
      final result = await DeleteAccountUseCase(repository)(
        const DeleteAccountParams(password: '', confirmation: 'EXCLUIR'),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('password_required')),
      );
      verifyNever(() => repository.deleteAccount(password: any(named: 'password')));
    });

    test('requires the confirmation word', () async {
      final result = await DeleteAccountUseCase(repository)(
        const DeleteAccountParams(password: 'senha123', confirmation: 'excluir tudo'),
      );

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('confirmation_mismatch')),
      );
      verifyNever(() => repository.deleteAccount(password: any(named: 'password')));
    });

    test('accepts the word in any case, with spaces around it', () async {
      when(() => repository.deleteAccount(password: 'senha123'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      final useCase = DeleteAccountUseCase(repository);

      for (final typed in ['EXCLUIR', 'excluir', '  Excluir ']) {
        final result = await useCase(
          DeleteAccountParams(password: 'senha123', confirmation: typed),
        );
        expect(result.isRight(), isTrue, reason: typed);
      }
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.deleteAccount(password: any(named: 'password')))
          .thenAnswer(
        (_) async =>
            const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );

      final result = await DeleteAccountUseCase(repository)(
        const DeleteAccountParams(password: 'errada123', confirmation: 'EXCLUIR'),
      );

      expect(
        result,
        const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
    });
  });
}