import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

abstract class CategoryRepository {
  /// Active (not archived) categories of a workspace, ordered by name.
  Future<Either<Failure, List<CategoryEntity>>> getCategories(
    String workspaceId,
  );
}