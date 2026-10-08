import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/data/datasources/audit_remote_data_source.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:finly/features/audit/domain/repositories/audit_repository.dart';

class AuditRepositoryImpl implements AuditRepository {
  final AuditRemoteDataSource _remote;

  const AuditRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<AuditRecord>>> getRecords(
    String workspaceId, {
    required int offset,
    required int limit,
    AuditFilter filter = AuditFilter.all,
  }) {
    return _guard<List<AuditRecord>>(
      () => _remote.getRecords(workspaceId, offset: offset, limit: limit, filter: filter),
    );
  }

  @override
  Future<Either<Failure, AuditLookup>> getLookup(String workspaceId) {
    return _guard<AuditLookup>(() => _remote.getLookup(workspaceId));
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error) are mapped to an unknown_error failure and logged.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}
