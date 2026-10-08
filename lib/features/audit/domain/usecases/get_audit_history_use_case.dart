import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/audit_rules.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:finly/features/audit/domain/repositories/audit_repository.dart';

class GetAuditHistoryParams extends Equatable {
  final String workspaceId;
  final int offset;
  final int limit;
  final AuditFilter filter;

  const GetAuditHistoryParams({
    required this.workspaceId,
    this.offset = 0,
    this.limit = GetAuditHistoryUseCase.pageSize,
    this.filter = AuditFilter.all,
  });

  @override
  List<Object?> get props => [workspaceId, offset, limit, filter];
}

/// A page of the history of changes of a workspace, written in plain words.
class GetAuditHistoryUseCase implements UseCase<AuditPage, GetAuditHistoryParams> {
  static const pageSize = 30;

  /// The most a page can have: a safety limit for the query.
  static const maxPageSize = 100;

  final AuditRepository _repository;

  const GetAuditHistoryUseCase(this._repository);

  @override
  Future<Either<Failure, AuditPage>> call(GetAuditHistoryParams params) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    if (params.offset < 0 || params.limit < 1 || params.limit > maxPageSize) {
      return const Left(ValidationFailure('invalid_page'));
    }

    final (recordsResult, lookupResult) = await (
      _repository.getRecords(
        params.workspaceId,
        offset: params.offset,
        limit: params.limit,
        filter: params.filter,
      ),
      _repository.getLookup(params.workspaceId),
    ).wait;

    Failure? failure;
    var records = const <AuditRecord>[];
    var lookup = const AuditLookup();
    recordsResult.fold((f) {
      failure = f;
    }, (value) {
      records = value;
    });
    lookupResult.fold((f) {
      failure ??= f;
    }, (value) {
      lookup = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, AuditPage>(problem);

    return Right<Failure, AuditPage>(
      AuditPage(
        items: [for (final record in records) describeAudit(record, lookup)],
        hasMore: records.length >= params.limit,
      ),
    );
  }
}
