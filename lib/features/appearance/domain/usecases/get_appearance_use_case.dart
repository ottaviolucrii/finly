import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/domain/repositories/appearance_repository.dart';

class GetAppearanceUseCase implements UseCase<AppearanceMode, NoParams> {
  final AppearanceRepository _repository;

  const GetAppearanceUseCase(this._repository);

  @override
  Future<Either<Failure, AppearanceMode>> call(NoParams params) {
    return _repository.getMode();
  }
}
