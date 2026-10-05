import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignUpUseCase useCase;

  const validParams = SignUpParams(
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    password: 'secret123',
    acceptedTerms: true,
  );

  const pendingResult = SignUpResult(
    email: 'ana@finly.com',
    needsEmailVerification: true,
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = SignUpUseCase(repository);
  });

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
        ));
  }

  Future<void> expectRejected(SignUpParams params, String code) async {
    final result = await useCase(params);
    expect(result, Left<Failure, SignUpResult>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects a too-short name', () async {
    await expectRejected(
      const SignUpParams(
        fullName: ' A ',
        email: 'ana@finly.com',
        password: 'secret123',
        acceptedTerms: true,
      ),
      'invalid_full_name',
    );
  });

  test('rejects an invalid e-mail', () async {
    await expectRejected(
      const SignUpParams(
        fullName: 'Ana Teste',
        email: 'ana@',
        password: 'secret123',
        acceptedTerms: true,
      ),
      'invalid_email',
    );
  });

  test('rejects a weak password', () async {
    await expectRejected(
      const SignUpParams(
        fullName: 'Ana Teste',
        email: 'ana@finly.com',
        password: 'abc',
        acceptedTerms: true,
      ),
      'weak_password',
    );
  });

  test('rejects when the terms are not accepted', () async {
    await expectRejected(
      const SignUpParams(
        fullName: 'Ana Teste',
        email: 'ana@finly.com',
        password: 'secret123',
        acceptedTerms: false,
      ),
      'terms_not_accepted',
    );
  });

  test('trims name and e-mail and returns the result on success', () async {
    when(() => repository.signUp(
          email: 'ana@finly.com',
          password: 'secret123',
          fullName: 'Ana Teste',
        )).thenAnswer(
      (_) async => const Right<Failure, SignUpResult>(pendingResult),
    );

    final result = await useCase(
      const SignUpParams(
        fullName: '  Ana Teste ',
        email: ' ana@finly.com ',
        password: 'secret123',
        acceptedTerms: true,
      ),
    );

    expect(result, const Right<Failure, SignUpResult>(pendingResult));
    verify(() => repository.signUp(
          email: 'ana@finly.com',
          password: 'secret123',
          fullName: 'Ana Teste',
        )).called(1);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          fullName: any(named: 'fullName'),
        )).thenAnswer(
      (_) async => const Left<Failure, SignUpResult>(
        AuthFailure('email_already_registered'),
      ),
    );

    final result = await useCase(validParams);

    expect(
      result,
      const Left<Failure, SignUpResult>(AuthFailure('email_already_registered')),
    );
  });
}