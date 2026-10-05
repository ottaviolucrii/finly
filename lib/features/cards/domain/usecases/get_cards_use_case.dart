import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';

/// Params: the workspace id.
class GetCardsUseCase implements UseCase<List<CreditCardEntity>, String> {
  final CardRepository _repository;

  const GetCardsUseCase(this._repository);

  @override
  Future<Either<Failure, List<CreditCardEntity>>> call(
    String workspaceId,
  ) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getCards(workspaceId);
  }
}