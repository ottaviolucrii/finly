import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:finly/features/reminders/domain/reminder_rules.dart';
import 'package:finly/features/reminders/domain/reminder_scheduler.dart';
import 'package:finly/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:flutter/foundation.dart';

class SyncRemindersParams extends Equatable {
  final String workspaceId;

  /// "Now"; any time of the day.
  final DateTime now;

  const SyncRemindersParams({required this.workspaceId, required this.now});

  @override
  List<Object?> get props => [workspaceId, now];
}

/// Rebuilds every scheduled reminder of the active workspace from the data: the
/// pending bills and the unpaid card invoices that are due soon. Returns how
/// many reminders were scheduled.
class SyncRemindersUseCase implements UseCase<int, SyncRemindersParams> {
  final RemindersRepository _repository;
  final ReminderScheduler _scheduler;

  const SyncRemindersUseCase(this._repository, this._scheduler);

  @override
  Future<Either<Failure, int>> call(SyncRemindersParams params) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final prefsResult = await _repository.getPrefs();
    NotificationPrefs? prefs;
    Failure? failure;
    prefsResult.fold((f) {
      failure = f;
    }, (value) {
      prefs = value;
    });
    final prefsProblem = failure;
    final loaded = prefs;
    if (prefsProblem != null || loaded == null) {
      return Left<Failure, int>(prefsProblem ?? const ServerFailure('unknown_error'));
    }

    try {
      // Everything off: nothing may be left scheduled from before.
      if (!loaded.anyEnabled) {
        await _scheduler.cancelAll();
        return const Right<Failure, int>(0);
      }

      final now = params.now;
      final from = DateTime(now.year, now.month, now.day);
      final to = DateTime(now.year, now.month, now.day + reminderWindowDays + 1);

      Future<Either<Failure, List<ReminderBill>>> loadBills() async {
        if (!loaded.billReminder) return const Right(<ReminderBill>[]);
        return _repository.getBills(workspaceId, from: from, to: to);
      }

      Future<Either<Failure, List<ReminderInvoice>>> loadInvoices() async {
        if (!loaded.cardDue) return const Right(<ReminderInvoice>[]);
        return _repository.getInvoices(workspaceId, from: from, to: to);
      }

      final (billsResult, invoicesResult) = await (loadBills(), loadInvoices()).wait;

      Failure? loadFailure;
      var bills = const <ReminderBill>[];
      var invoices = const <ReminderInvoice>[];
      billsResult.fold((f) {
        loadFailure ??= f;
      }, (value) {
        bills = value;
      });
      invoicesResult.fold((f) {
        loadFailure ??= f;
      }, (value) {
        invoices = value;
      });
      final problem = loadFailure;
      if (problem != null) return Left<Failure, int>(problem);

      final reminders = buildReminders(
        bills: bills,
        invoices: invoices,
        prefs: loaded,
        now: now,
      );
      return Right<Failure, int>(await _scheduler.replaceAll(reminders));
    } catch (e) {
      // The phone refused (or the plugin failed): not a data problem.
      debugPrint('Scheduling reminders failed: $e');
      return const Left(ServerFailure('notifications_error'));
    }
  }
}
