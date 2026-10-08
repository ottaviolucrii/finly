import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';

abstract class DataExportRepository {
  /// Reads every table that holds data of the signed-in user.
  Future<Either<Failure, UserDataSnapshot>> readAll();
}
