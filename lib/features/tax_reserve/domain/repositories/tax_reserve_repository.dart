import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';

abstract class TaxReserveRepository {
  /// The percentage of [workspaceId] and its income and taxes in [month].
  Future<Either<Failure, TaxReserveData>> getData(String workspaceId, DateTime month);

  /// Saves the percentage. The database accepts a value above zero only for a
  /// company workspace.
  Future<Either<Failure, void>> savePercent(String workspaceId, int percentBps);

  /// The expense categories of [workspaceId] that are not archived, by name,
  /// with whether each one counts as a tax.
  Future<Either<Failure, List<TaxCategory>>> getTaxCategories(String workspaceId);

  /// Marks a category as a tax, or not. The database accepts it only for an
  /// expense category.
  Future<Either<Failure, void>> setCategoryTax(String categoryId, {required bool isTax});
}
