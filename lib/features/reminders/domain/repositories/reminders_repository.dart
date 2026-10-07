import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';

abstract class RemindersRepository {
  Future<Either<Failure, NotificationPrefs>> getPrefs();

  Future<Either<Failure, void>> savePrefs(NotificationPrefs prefs);

  /// Pending expenses of [workspaceId] due from [from] (included) to [to]
  /// (excluded). Card purchases are not here: the invoice is the bill.
  Future<Either<Failure, List<ReminderBill>>> getBills(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });

  /// Unpaid invoices of the cards of [workspaceId] due from [from] (included)
  /// to [to] (excluded), with what they add up to.
  Future<Either<Failure, List<ReminderInvoice>>> getInvoices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });
}
