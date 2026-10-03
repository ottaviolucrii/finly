import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';

/// Params: the workspace id.
class GetCategoriesUseCase implements UseCase<List<CategoryEntity>, String> {
  final CategoryRepository _repository;

  const GetCategoriesUseCase(this._repository);

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(
    String workspaceId,
  ) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getCategories(workspaceId);
  }
}