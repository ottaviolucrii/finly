import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';

class UpdateCategoryParams extends Equatable {
  final String categoryId;
  final String name;
  final String icon;
  final String colorHex;

  const UpdateCategoryParams({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.colorHex,
  });

  @override
  List<Object?> get props => [categoryId, name, icon, colorHex];
}

/// Changes the name, icon and colour of a category. The kind never changes.
class UpdateCategoryUseCase
    implements UseCase<CategoryEntity, UpdateCategoryParams> {
  final CategoryRepository _repository;

  const UpdateCategoryUseCase(this._repository);

  @override
  Future<Either<Failure, CategoryEntity>> call(
    UpdateCategoryParams params,
  ) async {
    if (params.categoryId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_category'));
    }
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

    return _repository.updateCategory(
      categoryId: params.categoryId,
      name: name,
      icon: params.icon,
      colorHex: params.colorHex,
    );
  }
}