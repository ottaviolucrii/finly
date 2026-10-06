import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/request_password_reset_use_case.dart';
import 'package:finly/features/auth/domain/usecases/reset_password_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  group('RequestPasswordResetUseCase', () {
    test('rejects an invalid e-mail', () async {
      final result = await RequestPasswordResetUseCase(repository)('not-an-email');

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_email')),
      );
      verifyNever(() => repository.requestPasswordReset(email: any(named: 'email')));
    });

    test('trims the e-mail and forwards it', () async {
      when(() => repository.requestPasswordReset(email: 'ana@exemplo.com'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result =
          await RequestPasswordResetUseCase(repository)('  ana@exemplo.com ');

      expect(result.isRight(), isTrue);
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.requestPasswordReset(email: any(named: 'email')))
          .thenAnswer(
        (_) async => const Left<Failure, void>(AuthFailure('rate_limited')),
      );

      final result =
          await RequestPasswordResetUseCase(repository)('ana@exemplo.com');

      expect(result, const Left<Failure, void>(AuthFailure('rate_limited')));
    });
  });

  group('ResetPasswordUseCase', () {
    ResetPasswordParams params({
      String email = 'ana@exemplo.com',
      String code = '123456',
      String newPassword = 'novaSenha2',
    }) {
      return ResetPasswordParams(
        email: email,
        code: code,
        newPassword: newPassword,
      );
    }

    void verifyNotCalled() {
      verifyNever(() => repository.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          ));
    }

    Future<void> expectRejected(ResetPasswordParams p, String code) async {
      final result = await ResetPasswordUseCase(repository)(p);
      expect(result, Left<Failure, void>(ValidationFailure(code)));
      verifyNotCalled();
    }

    test('rejects an invalid e-mail', () async {
      await expectRejected(params(email: 'x'), 'invalid_email');
    });

    test('rejects a code that is not 6 to 10 digits', () async {
      await expectRejected(params(code: '12345'), 'invalid_code');
      await expectRejected(params(code: '12345678901'), 'invalid_code');
      await expectRejected(params(code: '12a456'), 'invalid_code');
      await expectRejected(params(code: ''), 'invalid_code');
    });

    test('rejects a weak password before the code is spent', () async {
      await expectRejected(params(newPassword: 'curta1'), 'weak_password');
      await expectRejected(params(newPassword: 'somenteletras'), 'weak_password');
      await expectRejected(params(newPassword: '12345678'), 'weak_password');
    });

    test('trims the e-mail and the code and forwards them', () async {
      when(() => repository.resetPassword(
            email: 'ana@exemplo.com',
            code: '123456',
            newPassword: 'novaSenha2',
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await ResetPasswordUseCase(repository)(
        params(email: ' ana@exemplo.com ', code: ' 123456 '),
      );

      expect(result.isRight(), isTrue);
    });

    test('passes a wrong code failure through unchanged', () async {
      when(() => repository.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          )).thenAnswer(
        (_) async => const Left<Failure, void>(AuthFailure('invalid_code')),
      );

      final result = await ResetPasswordUseCase(repository)(params());

      expect(result, const Left<Failure, void>(AuthFailure('invalid_code')));
    });
  });
}