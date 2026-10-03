import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryRemoteDataSource _remote;

  const CategoryRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<CategoryEntity>>> getCategories(
    String workspaceId,
  ) async {
    try {
      final categories = await _remote.getCategories(workspaceId);
      return Right<Failure, List<CategoryEntity>>(categories);
    } on Exception catch (e) {
      return Left<Failure, List<CategoryEntity>>(ErrorMapper.toFailure(e));
    }
  }
}