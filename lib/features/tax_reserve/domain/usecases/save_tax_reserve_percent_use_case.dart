import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';
import 'package:finly/features/tax_reserve/domain/tax_reserve_rules.dart';

class SaveTaxReservePercentParams extends Equatable {
  final String workspaceId;
  final int percentBps;

  const SaveTaxReservePercentParams({
    required this.workspaceId,
    required this.percentBps,
  });

  @override
  List<Object?> get props => [workspaceId, percentBps];
}

/// Saves the share of the income a company sets aside for taxes.
class SaveTaxReservePercentUseCase
    implements UseCase<void, SaveTaxReservePercentParams> {
  final TaxReserveRepository _repository;

  const SaveTaxReservePercentUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SaveTaxReservePercentParams params) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    if (params.percentBps < 0 || params.percentBps > maxPercentBps) {
      return const Left(ValidationFailure('invalid_percent'));
    }
    return _repository.savePercent(params.workspaceId, params.percentBps);
  }
}
