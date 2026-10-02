import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/domain/repositories/workspace_repository.dart';

class CreateWorkspaceParams extends Equatable {
  final String name;
  final WorkspaceType type;
  final String taxId;

  const CreateWorkspaceParams({
    required this.name,
    required this.type,
    required this.taxId,
  });

  @override
  List<Object?> get props => [name, type, taxId];
}

class CreateWorkspaceUseCase
    implements UseCase<WorkspaceEntity, CreateWorkspaceParams> {
  final WorkspaceRepository _repository;

  const CreateWorkspaceUseCase(this._repository);

  @override
  Future<Either<Failure, WorkspaceEntity>> call(
    CreateWorkspaceParams params,
  ) async {
    final name = params.name.trim();
    if (name.isEmpty || name.length > 80) {
      return const Left(ValidationFailure('invalid_workspace_name'));
    }

    // Personal needs a CPF, Business needs a CNPJ (SRS BR-06).
    final taxId = Validators.normalizeTaxId(params.taxId);
    final taxIdIsValid = switch (params.type) {
      WorkspaceType.personal => Validators.isValidCPF(taxId),
      WorkspaceType.business => Validators.isValidCNPJ(taxId),
    };
    if (!taxIdIsValid) {
      return const Left(ValidationFailure('invalid_tax_id'));
    }

    return _repository.createWorkspace(
      name: name,
      type: params.type,
      taxId: taxId,
    );
  }
}