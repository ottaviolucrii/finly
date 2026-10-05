import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSwitchWorkspace extends Mock implements SwitchWorkspaceUseCase {}

void main() {
  late MockSwitchWorkspace switchWorkspace;

  const params = SwitchWorkspaceParams(workspaceId: 'w2');
  const user = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
    activeWorkspaceId: 'w2',
  );

  setUp(() => switchWorkspace = MockSwitchWorkspace());

  blocTest<SwitchWorkspaceCubit, SwitchWorkspaceState>(
    'emits switching then success carrying the updated user',
    build: () {
      when(() => switchWorkspace(params))
          .thenAnswer((_) async => const Right<Failure, UserEntity>(user));
      return SwitchWorkspaceCubit(switchWorkspace);
    },
    act: (cubit) => cubit.switchTo('w2'),
    expect: () => [
      const SwitchWorkspaceState(status: SwitchWorkspaceStatus.switching),
      const SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.success,
        user: user,
      ),
    ],
  );

  blocTest<SwitchWorkspaceCubit, SwitchWorkspaceState>(
    'emits switching then failure with the reason',
    build: () {
      when(() => switchWorkspace(params)).thenAnswer(
        (_) async =>
            const Left<Failure, UserEntity>(PermissionFailure('forbidden')),
      );
      return SwitchWorkspaceCubit(switchWorkspace);
    },
    act: (cubit) => cubit.switchTo('w2'),
    expect: () => [
      const SwitchWorkspaceState(status: SwitchWorkspaceStatus.switching),
      const SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.failure,
        failure: PermissionFailure('forbidden'),
      ),
    ],
  );

  blocTest<SwitchWorkspaceCubit, SwitchWorkspaceState>(
    'calls the use case once with the chosen workspace',
    build: () {
      when(() => switchWorkspace(params))
          .thenAnswer((_) async => const Right<Failure, UserEntity>(user));
      return SwitchWorkspaceCubit(switchWorkspace);
    },
    act: (cubit) => cubit.switchTo('w2'),
    verify: (_) => verify(() => switchWorkspace(params)).called(1),
  );

  blocTest<SwitchWorkspaceCubit, SwitchWorkspaceState>(
    'a call that never answers ends in a failure instead of staying stuck',
    build: () {
      when(() => switchWorkspace(params)).thenAnswer(
        (_) => Completer<Either<Failure, UserEntity>>().future,
      );
      return SwitchWorkspaceCubit(
        switchWorkspace,
        timeout: const Duration(milliseconds: 20),
      );
    },
    act: (cubit) => cubit.switchTo('w2'),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      const SwitchWorkspaceState(status: SwitchWorkspaceStatus.switching),
      const SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<SwitchWorkspaceCubit, SwitchWorkspaceState>(
    'an unexpected error also ends in a failure instead of staying stuck',
    build: () {
      when(() => switchWorkspace(params)).thenThrow(StateError('boom'));
      return SwitchWorkspaceCubit(switchWorkspace);
    },
    act: (cubit) => cubit.switchTo('w2'),
    expect: () => [
      const SwitchWorkspaceState(status: SwitchWorkspaceStatus.switching),
      const SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.failure,
        failure: RuleFailure('unexpected_error'),
      ),
    ],
  );

  blocTest<SwitchWorkspaceCubit, SwitchWorkspaceState>(
    'a new switch can start after a failure',
    build: () {
      when(() => switchWorkspace(params)).thenAnswer(
        (_) async =>
            const Left<Failure, UserEntity>(NetworkFailure('network_error')),
      );
      return SwitchWorkspaceCubit(switchWorkspace);
    },
    act: (cubit) async {
      await cubit.switchTo('w2');
      await cubit.switchTo('w2');
    },
    verify: (_) => verify(() => switchWorkspace(params)).called(2),
  );
}