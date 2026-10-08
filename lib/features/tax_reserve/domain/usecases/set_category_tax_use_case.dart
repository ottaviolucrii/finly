import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';

class SetCategoryTaxParams extends Equatable {
  final String categoryId;
  final bool isTax;

  const SetCategoryTaxParams({required this.categoryId, required this.isTax});

  @override
  List<Object?> get props => [categoryId, isTax];
}

/// Marks an expense category as a tax (or takes the mark off).
class SetCategoryTaxUseCase implements UseCase<void, SetCategoryTaxParams> {
  final TaxReserveRepository _repository;

  const SetCategoryTaxUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SetCategoryTaxParams params) async {
    if (params.categoryId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_category'));
    }
    return _repository.setCategoryTax(params.categoryId, isTax: params.isTax);
  }
}
