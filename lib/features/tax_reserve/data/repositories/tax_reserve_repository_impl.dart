import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/data/datasources/tax_reserve_remote_data_source.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';

class TaxReserveRepositoryImpl implements TaxReserveRepository {
  final TaxReserveRemoteDataSource _remote;

  const TaxReserveRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, TaxReserveData>> getData(String workspaceId, DateTime month) {
    return _guard<TaxReserveData>(() => _remote.getData(workspaceId, month));
  }

  @override
  Future<Either<Failure, void>> savePercent(String workspaceId, int percentBps) {
    return _guard<void>(() => _remote.savePercent(workspaceId, percentBps));
  }

  @override
  Future<Either<Failure, List<TaxCategory>>> getTaxCategories(String workspaceId) {
    return _guard<List<TaxCategory>>(() => _remote.getTaxCategories(workspaceId));
  }

  @override
  Future<Either<Failure, void>> setCategoryTax(String categoryId, {required bool isTax}) {
    return _guard<void>(() => _remote.setCategoryTax(categoryId, isTax: isTax));
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error) are mapped to an unknown_error failure and logged.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}
