import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reminders/data/datasources/reminders_remote_data_source.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:finly/features/reminders/domain/repositories/reminders_repository.dart';

class RemindersRepositoryImpl implements RemindersRepository {
  final RemindersRemoteDataSource _remote;

  const RemindersRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, NotificationPrefs>> getPrefs() {
    return _guard<NotificationPrefs>(() => _remote.getPrefs());
  }

  @override
  Future<Either<Failure, void>> savePrefs(NotificationPrefs prefs) {
    return _guard<void>(() => _remote.savePrefs(prefs));
  }

  @override
  Future<Either<Failure, List<ReminderBill>>> getBills(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _guard<List<ReminderBill>>(
      () => _remote.getBills(workspaceId, from: from, to: to),
    );
  }

  @override
  Future<Either<Failure, List<ReminderInvoice>>> getInvoices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _guard<List<ReminderInvoice>>(
      () => _remote.getInvoices(workspaceId, from: from, to: to),
    );
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
