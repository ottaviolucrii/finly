import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';

class GetTaxReserveParams extends Equatable {
  final String workspaceId;

  /// Any day of the month.
  final DateTime month;

  const GetTaxReserveParams({required this.workspaceId, required this.month});

  @override
  List<Object?> get props => [workspaceId, month];
}

/// The tax reserve of a company workspace for one month.
class GetTaxReserveUseCase implements UseCase<TaxReserveData, GetTaxReserveParams> {
  final TaxReserveRepository _repository;

  const GetTaxReserveUseCase(this._repository);

  @override
  Future<Either<Failure, TaxReserveData>> call(GetTaxReserveParams params) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final month = DateTime(params.month.year, params.month.month);
    return _repository.getData(params.workspaceId, month);
  }
}
