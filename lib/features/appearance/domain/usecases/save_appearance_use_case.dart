import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/domain/repositories/appearance_repository.dart';

class SaveAppearanceUseCase implements UseCase<void, AppearanceMode> {
  final AppearanceRepository _repository;

  const SaveAppearanceUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(AppearanceMode mode) {
    return _repository.saveMode(mode);
  }
}
