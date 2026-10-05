import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/domain/usecases/create_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateWorkspace extends Mock implements CreateWorkspaceUseCase {}

void main() {
  late MockCreateWorkspace createWorkspace;

  const params = CreateWorkspaceParams(
    name: 'Pessoal',
    type: WorkspaceType.personal,
    taxId: '52998224725',
  );
  const workspace = WorkspaceEntity(
    id: 'w1',
    ownerId: 'u1',
    name: 'Pessoal',
    taxId: '52998224725',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );

  setUpAll(() => registerFallbackValue(params));

  setUp(() => createWorkspace = MockCreateWorkspace());

  blocTest<OnboardingCubit, OnboardingState>(
    'choosing a type moves to the form',
    build: () => OnboardingCubit(createWorkspace),
    act: (cubit) => cubit.selectType(WorkspaceType.business),
    expect: () => [const OnboardingState(type: WorkspaceType.business)],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'going back returns to the type chooser',
    build: () => OnboardingCubit(createWorkspace),
    seed: () => const OnboardingState(type: WorkspaceType.personal),
    act: (cubit) => cubit.backToTypes(),
    expect: () => [const OnboardingState()],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'submit emits submitting then success',
    build: () {
      when(() => createWorkspace(params)).thenAnswer(
        (_) async => const Right<Failure, WorkspaceEntity>(workspace),
      );
      return OnboardingCubit(createWorkspace);
    },
    seed: () => const OnboardingState(type: WorkspaceType.personal),
    act: (cubit) => cubit.submit(name: 'Pessoal', taxId: '52998224725'),
    expect: () => [
      const OnboardingState(
        type: WorkspaceType.personal,
        status: OnboardingStatus.submitting,
      ),
      const OnboardingState(
        type: WorkspaceType.personal,
        status: OnboardingStatus.success,
        workspace: workspace,
      ),
    ],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'submit emits submitting then failure and keeps the chosen type',
    build: () {
      when(() => createWorkspace(params)).thenAnswer(
        (_) async => const Left<Failure, WorkspaceEntity>(
          ValidationFailure('invalid_tax_id'),
        ),
      );
      return OnboardingCubit(createWorkspace);
    },
    seed: () => const OnboardingState(type: WorkspaceType.personal),
    act: (cubit) => cubit.submit(name: 'Pessoal', taxId: '52998224725'),
    expect: () => [
      const OnboardingState(
        type: WorkspaceType.personal,
        status: OnboardingStatus.submitting,
      ),
      const OnboardingState(
        type: WorkspaceType.personal,
        status: OnboardingStatus.failure,
        failure: ValidationFailure('invalid_tax_id'),
      ),
    ],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'submit does nothing before a type is chosen',
    build: () => OnboardingCubit(createWorkspace),
    act: (cubit) => cubit.submit(name: 'Pessoal', taxId: '52998224725'),
    expect: () => <OnboardingState>[],
    verify: (_) => verifyNever(() => createWorkspace(any())),
  );
}