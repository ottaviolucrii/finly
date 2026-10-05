import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/data/models/workspace_model.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/data/datasources/workspace_remote_data_source.dart';
import 'package:finly/features/workspaces/data/repositories/workspace_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements WorkspaceRemoteDataSource {}

void main() {
  late MockRemote remote;
  late WorkspaceRepositoryImpl repository;

  const workspace = WorkspaceModel(
    id: 'w1',
    ownerId: 'u1',
    name: 'Pessoal',
    taxId: '52998224725',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );

  setUp(() {
    remote = MockRemote();
    repository = WorkspaceRepositoryImpl(remote);
  });

  Future<Either<Failure, WorkspaceEntity>> create() {
    return repository.createWorkspace(
      name: 'Pessoal',
      type: WorkspaceType.personal,
      taxId: '52998224725',
    );
  }

  test('returns the created workspace', () async {
    when(() => remote.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).thenAnswer((_) async => workspace);

    expect(await create(), const Right<Failure, WorkspaceEntity>(workspace));
  });

  test('maps an invalid tax id from the database to ValidationFailure',
      () async {
    when(() => remote.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).thenThrow(
      PostgrestException(message: 'invalid_tax_id', code: '22023'),
    );

    expect(
      await create(),
      const Left<Failure, WorkspaceEntity>(ValidationFailure('invalid_tax_id')),
    );
  });

  test('maps a duplicate workspace type to ConflictFailure', () async {
    when(() => remote.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).thenThrow(
      PostgrestException(
        message: 'workspace_type_already_exists',
        code: '23505',
      ),
    );

    expect(
      await create(),
      const Left<Failure, WorkspaceEntity>(
        ConflictFailure('workspace_type_already_exists'),
      ),
    );
  });

  test('maps a timeout to NetworkFailure', () async {
    when(() => remote.createWorkspace(
          name: 'Pessoal',
          type: WorkspaceType.personal,
          taxId: '52998224725',
        )).thenThrow(TimeoutException('slow'));

    expect(
      await create(),
      const Left<Failure, WorkspaceEntity>(NetworkFailure('network_error')),
    );
  });
}