import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignInUseCase useCase;

  const user = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = SignInUseCase(repository);
  });

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  }

  test('rejects an invalid e-mail without calling the repository', () async {
    final result = await useCase(
      const SignInParams(email: 'not-an-email', password: 'secret123'),
    );

    expect(
      result,
      const Left<Failure, UserEntity>(ValidationFailure('invalid_email')),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects an empty password without calling the repository', () async {
    final result = await useCase(
      const SignInParams(email: 'ana@finly.com', password: ''),
    );

    expect(
      result,
      const Left<Failure, UserEntity>(ValidationFailure('password_required')),
    );
    verifyRepositoryNotCalled();
  });

  test('trims the e-mail and returns the user on success', () async {
    when(() => repository.signIn(email: 'ana@finly.com', password: 'secret123'))
        .thenAnswer((_) async => const Right<Failure, UserEntity>(user));

    final result = await useCase(
      const SignInParams(email: '  ana@finly.com ', password: 'secret123'),
    );

    expect(result, const Right<Failure, UserEntity>(user));
    verify(() => repository.signIn(email: 'ana@finly.com', password: 'secret123'))
        .called(1);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.signIn(email: 'ana@finly.com', password: 'wrong'))
        .thenAnswer(
      (_) async => const Left<Failure, UserEntity>(
        AuthFailure('invalid_credentials'),
      ),
    );

    final result = await useCase(
      const SignInParams(email: 'ana@finly.com', password: 'wrong'),
    );

    expect(
      result,
      const Left<Failure, UserEntity>(AuthFailure('invalid_credentials')),
    );
  });
}