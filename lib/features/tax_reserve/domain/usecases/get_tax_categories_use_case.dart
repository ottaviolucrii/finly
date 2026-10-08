import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';

/// The expense categories of a workspace, each with its "is a tax" flag.
class GetTaxCategoriesUseCase implements UseCase<List<TaxCategory>, String> {
  final TaxReserveRepository _repository;

  const GetTaxCategoriesUseCase(this._repository);

  @override
  Future<Either<Failure, List<TaxCategory>>> call(String workspaceId) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getTaxCategories(workspaceId);
  }
}
