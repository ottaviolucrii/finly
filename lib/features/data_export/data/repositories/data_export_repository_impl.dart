import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/data_export/data/datasources/data_export_remote_data_source.dart';
import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';
import 'package:finly/features/data_export/domain/repositories/data_export_repository.dart';

class DataExportRepositoryImpl implements DataExportRepository {
  final DataExportRemoteDataSource _remote;

  const DataExportRepositoryImpl(this._remote);

  /// Exceptions become Left(Failure). Programming errors (Error) are mapped to
  /// an unknown_error failure and logged.
  @override
  Future<Either<Failure, UserDataSnapshot>> readAll() async {
    try {
      return Right<Failure, UserDataSnapshot>(await _remote.readAll());
    } catch (e) {
      return Left<Failure, UserDataSnapshot>(ErrorMapper.toFailure(e));
    }
  }
}
