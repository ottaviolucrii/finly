import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late GetCurrentUserUseCase useCase;

  const user = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = GetCurrentUserUseCase(repository);
  });

  test('returns the signed-in user', () async {
    when(() => repository.getCurrentUser())
        .thenAnswer((_) async => const Right<Failure, UserEntity?>(user));

    final result = await useCase(const NoParams());

    expect(result, const Right<Failure, UserEntity?>(user));
  });

  test('returns null when nobody is signed in', () async {
    when(() => repository.getCurrentUser())
        .thenAnswer((_) async => const Right<Failure, UserEntity?>(null));

    final result = await useCase(const NoParams());

    expect(result, const Right<Failure, UserEntity?>(null));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.getCurrentUser()).thenAnswer(
      (_) async =>
          const Left<Failure, UserEntity?>(NetworkFailure('network_error')),
    );

    final result = await useCase(const NoParams());

    expect(
      result,
      const Left<Failure, UserEntity?>(NetworkFailure('network_error')),
    );
  });
}