import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/domain/repositories/workspace_repository.dart';
import 'package:finly/features/workspaces/domain/usecases/create_workspace_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkspaceRepository extends Mock implements WorkspaceRepository {}

void main() {
  late MockWorkspaceRepository repository;
  late CreateWorkspaceUseCase useCase;

  const personal = WorkspaceEntity(
    id: 'w1',
    ownerId: 'u1',
    name: 'Pessoal',
    taxId: '52998224725',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );
  const business = WorkspaceEntity(
    id: 'w2',
    ownerId: 'u1',
    name: 'Minha Empresa',
    taxId: '00000000E08G12',
    taxIdType: TaxIdType.cnpj,
    type: WorkspaceType.business,
  );

  setUpAll(() => registerFallbackValue(WorkspaceType.personal));

  setUp(() {
    repository = MockWorkspaceRepository();
    useCase = CreateWorkspaceUseCase(repository);
  });

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createWorkspace(
          name: any(named: 'name'),
          type: any(named: 'type'),
          taxId: any(named: 'taxId'),
        ));
  }

  test('rejects an empty name', () async {
    final result = await useCase(const CreateWorkspaceParams(
      name: '   ',
      type: WorkspaceType.personal,
      taxId: '529.982.247-25',
    ));

    expect(
      result,
      const Left<Failure, WorkspaceEntity>(
        ValidationFailure('invalid_workspace_name'),
      ),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects a name longer than 80 characters', () async {
    final result = await useCase(CreateWorkspaceParams(
      name: 'a' * 81,
      type: WorkspaceType.personal,
      taxId: '529.982.247-25',
    ));

    expect(
      result,
      const Left<Failure, WorkspaceEntity>(
        ValidationFailure('invalid_workspace_name'),
      ),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects a personal workspace with a wrong CPF', () async {
    final result = await useCase(const CreateWorkspaceParams(
      name: 'Pessoal',
      type: WorkspaceType.personal,
      taxId: '529.982.247-26',
    ));

    expect(
      result,
      const Left<Failure, WorkspaceEntity>(ValidationFailure('invalid_tax_id')),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects a personal workspace with a CNPJ', () async {
    final result = await useCase(const CreateWorkspaceParams(
      name: 'Pessoal',
      type: WorkspaceType.personal,
      taxId: '11.222.333/0001-81',
    ));

    expect(
      result,
      const Left<Failure, WorkspaceEntity>(ValidationFailure('invalid_tax_id')),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects a business workspace with a CPF', () async {
    final result = await useCase(const CreateWorkspaceParams(
      name: 'Minha Empresa',
      type: WorkspaceType.business,
      taxId: '529.982.247-25',
    ));

    expect(
      result,
      const Left<Failure, WorkspaceEntity>(ValidationFailure('invalid_tax_id')),
    );
    verifyRepositoryNotCalled();
  });

  test('trims the name, normalises the CPF and returns the workspace', () async {
    when(() => repository.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).thenAnswer(
      (_) async => const Right<Failure, WorkspaceEntity>(personal),
    );

    final result = await useCase(const CreateWorkspaceParams(
      name: '  Pessoal ',
      type: WorkspaceType.personal,
      taxId: '529.982.247-25',
    ));

    expect(result, const Right<Failure, WorkspaceEntity>(personal));
    verify(() => repository.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).called(1);
  });

  test('accepts an alphanumeric CNPJ typed in lower case with a mask', () async {
    when(() => repository.createWorkspace(
          name: 'Minha Empresa',
          type: WorkspaceType.business,
          taxId: '00000000E08G12',
        )).thenAnswer(
      (_) async => const Right<Failure, WorkspaceEntity>(business),
    );

    final result = await useCase(const CreateWorkspaceParams(
      name: 'Minha Empresa',
      type: WorkspaceType.business,
      taxId: '00.000.000/e08g-12',
    ));

    expect(result, const Right<Failure, WorkspaceEntity>(business));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).thenAnswer(
      (_) async => const Left<Failure, WorkspaceEntity>(
        ConflictFailure('workspace_type_already_exists'),
      ),
    );

    final result = await useCase(const CreateWorkspaceParams(
      name: 'Pessoal',
      type: WorkspaceType.personal,
      taxId: '529.982.247-25',
    ));

    expect(
      result,
      const Left<Failure, WorkspaceEntity>(
        ConflictFailure('workspace_type_already_exists'),
      ),
    );
  });
}