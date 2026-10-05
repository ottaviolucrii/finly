import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    name: 'Empresa',
    taxId: '11222333000181',
    taxIdType: TaxIdType.cnpj,
    type: WorkspaceType.business,
  );

  UserEntity userWith(List<WorkspaceEntity> workspaces, {String? activeId}) {
    return UserEntity(
      id: 'u1',
      fullName: 'Ana Teste',
      email: 'ana@finly.com',
      workspaces: workspaces,
      activeWorkspaceId: activeId,
    );
  }

  group('activeWorkspace', () {
    test('returns the workspace with the active id', () {
      final user = userWith([personal, business], activeId: 'w2');

      expect(user.activeWorkspace, business);
    });

    test('is null when no workspace is active', () {
      expect(userWith([personal]).activeWorkspace, isNull);
    });

    test('is null when the active id matches no workspace', () {
      expect(userWith([personal], activeId: 'other').activeWorkspace, isNull);
    });
  });

  group('missingWorkspaceType', () {
    test('is null when the user has no workspace yet', () {
      expect(userWith([]).missingWorkspaceType, isNull);
    });

    test('is business when only a personal workspace exists', () {
      expect(userWith([personal]).missingWorkspaceType, WorkspaceType.business);
    });

    test('is personal when only a business workspace exists', () {
      expect(userWith([business]).missingWorkspaceType, WorkspaceType.personal);
    });

    test('is null when both exist', () {
      expect(userWith([personal, business]).missingWorkspaceType, isNull);
    });
  });
}