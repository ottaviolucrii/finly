import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource _remote;

  const CategoryRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories(
    String workspaceId,
  ) {
    return _guard<List<CategoryEntity>>(() => _remote.getCategories(workspaceId));
  }

  @override
  Future<Either<Failure, List<CategoryEntity>>> getAllCategories(
    String workspaceId,
  ) {
    return _guard<List<CategoryEntity>>(
      () => _remote.getAllCategories(workspaceId),
    );
  }

  @override
  Future<Either<Failure, CategoryEntity>> createCategory({
    required String workspaceId,
    required String name,
    required CategoryKind kind,
    required String icon,
    required String colorHex,
  }) {
    return _guard<CategoryEntity>(
      () => _remote.createCategory(
        workspaceId: workspaceId,
        name: name,
        kind: kind,
        icon: icon,
        colorHex: colorHex,
      ),
    );
  }

  @override
  Future<Either<Failure, CategoryEntity>> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
    required String colorHex,
  }) {
    return _guard<CategoryEntity>(
      () => _remote.updateCategory(
        categoryId: categoryId,
        name: name,
        icon: icon,
        colorHex: colorHex,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> setArchived(
    String categoryId, {
    required bool archived,
  }) {
    return _guard<void>(
      () => _remote.setArchived(categoryId, archived: archived),
    );
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error, not Exception) are not caught on purpose.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } on Exception catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}