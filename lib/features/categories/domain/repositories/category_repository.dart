import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';

abstract class CategoryRepository {
  /// Active (not archived) categories of a workspace, ordered by name.
  Future<Either<Failure, List<CategoryEntity>>> getCategories(
    String workspaceId,
  );

  /// Every category of a workspace, archived ones included, ordered by name.
  Future<Either<Failure, List<CategoryEntity>>> getAllCategories(
    String workspaceId,
  );

  Future<Either<Failure, CategoryEntity>> createCategory({
    required String workspaceId,
    required String name,
    required CategoryKind kind,
    required String icon,
    required String colorHex,
  });

  /// Changes the name, icon and colour. The kind never changes.
  Future<Either<Failure, CategoryEntity>> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
    required String colorHex,
  });

  /// Archives or restores a category. Nothing is deleted.
  Future<Either<Failure, void>> setArchived(
    String categoryId, {
    required bool archived,
  });
}