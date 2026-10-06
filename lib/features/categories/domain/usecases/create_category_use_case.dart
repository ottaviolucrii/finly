import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';

/// A colour such as "#F29D38": what the database accepts.
final RegExp categoryColorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

class CreateCategoryParams extends Equatable {
  final String workspaceId;
  final String name;
  final CategoryKind kind;
  final String icon;
  final String colorHex;

  const CreateCategoryParams({
    required this.workspaceId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.colorHex,
  });

  @override
  List<Object?> get props => [workspaceId, name, kind, icon, colorHex];
}

class CreateCategoryUseCase
    implements UseCase<CategoryEntity, CreateCategoryParams> {
  final CategoryRepository _repository;

  const CreateCategoryUseCase(this._repository);

  @override
  Future<Either<Failure, CategoryEntity>> call(
    CreateCategoryParams params,
  ) async {
    final name = params.name.trim();
    if (name.isEmpty || name.length > 60) {
      return const Left(ValidationFailure('invalid_category_name'));
    }
    if (params.icon.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_icon'));
    }
    if (!categoryColorPattern.hasMatch(params.colorHex)) {
      return const Left(ValidationFailure('invalid_color'));
    }

    return _repository.createCategory(
      workspaceId: params.workspaceId,
      name: name,
      kind: params.kind,
      icon: params.icon,
      colorHex: params.colorHex,
    );
  }
}