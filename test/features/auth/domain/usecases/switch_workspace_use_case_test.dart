import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';
import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SwitchWorkspaceUseCase useCase;

  const user = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
    activeWorkspaceId: 'w2',
  );

  setUp(() {
    repository = MockAuthRepository();
    useCase = SwitchWorkspaceUseCase(repository);
  });

  test('rejects an empty workspace id without calling the repository',
      () async {
    final result = await useCase(const SwitchWorkspaceParams(workspaceId: ' '));

    expect(
      result,
      const Left<Failure, UserEntity>(ValidationFailure('invalid_workspace')),
    );
    verifyNever(() => repository.switchWorkspace(any()));
  });

  test('returns the user with the new active workspace', () async {
    when(() => repository.switchWorkspace('w2'))
        .thenAnswer((_) async => const Right<Failure, UserEntity>(user));

    final result =
        await useCase(const SwitchWorkspaceParams(workspaceId: 'w2'));

    expect(result, const Right<Failure, UserEntity>(user));
    verify(() => repository.switchWorkspace('w2')).called(1);
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.switchWorkspace('w9')).thenAnswer(
      (_) async =>
          const Left<Failure, UserEntity>(PermissionFailure('forbidden')),
    );

    final result =
        await useCase(const SwitchWorkspaceParams(workspaceId: 'w9'));

    expect(
      result,
      const Left<Failure, UserEntity>(PermissionFailure('forbidden')),
    );
  });
}