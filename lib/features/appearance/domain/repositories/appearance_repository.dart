import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';

abstract class AppearanceRepository {
  /// The choice of the signed-in user.
  Future<Either<Failure, AppearanceMode>> getMode();

  Future<Either<Failure, void>> saveMode(AppearanceMode mode);
}
