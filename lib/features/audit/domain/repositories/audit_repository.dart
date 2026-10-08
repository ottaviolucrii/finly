import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';

abstract class AuditRepository {
  /// A page of the audit log of [workspaceId], newest first. [filter] keeps only
  /// some tables.
  Future<Either<Failure, List<AuditRecord>>> getRecords(
    String workspaceId, {
    required int offset,
    required int limit,
    AuditFilter filter = AuditFilter.all,
  });

  /// The names of the accounts and categories of [workspaceId], for the ids
  /// that appear in the log.
  Future<Either<Failure, AuditLookup>> getLookup(String workspaceId);
}
