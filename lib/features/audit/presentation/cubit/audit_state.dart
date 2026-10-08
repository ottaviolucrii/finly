import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';

enum AuditStatus { loading, loaded, failure }

class AuditState extends Equatable {
  final AuditStatus status;
  final AuditFilter filter;

  /// What is on screen, newest first. It stays while the next page loads.
  final List<AuditItem> items;

  /// True when the last page was full, so there may be more.
  final bool hasMore;

  /// True while the next page is being read.
  final bool loadingMore;
  final Failure? failure;

  const AuditState({
    this.status = AuditStatus.loading,
    this.filter = AuditFilter.all,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  @override
  List<Object?> get props => [status, filter, items, hasMore, loadingMore, failure];
}
