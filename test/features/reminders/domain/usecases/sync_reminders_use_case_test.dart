import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:finly/features/reminders/domain/reminder_scheduler.dart';
import 'package:finly/features/reminders/domain/repositories/reminders_repository.dart';
import 'package:finly/features/reminders/domain/usecases/sync_reminders_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements RemindersRepository {}

class MockScheduler extends Mock implements ReminderScheduler {}

void main() {
  late MockRepository repository;
  late MockScheduler scheduler;
  late SyncRemindersUseCase useCase;

  final now = DateTime(2026, 10, 6, 7);
  final params = SyncRemindersParams(workspaceId: 'w1', now: now);

  final bill = ReminderBill(
    id: 'b1',
    description: 'Aluguel',
    amountCents: 150000,
    currency: 'BRL',
    dueDate: DateTime(2026, 10, 9),
  );
  final invoice = ReminderInvoice(
    id: 'i1',
    cardName: 'Nubank',
    totalCents: 80000,
    currency: 'BRL',
    dueDate: DateTime(2026, 10, 17),
  );

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<ScheduledReminder>[]);
  });

  setUp(() {
    repository = MockRepository();
    scheduler = MockScheduler();
    useCase = SyncRemindersUseCase(repository, scheduler);

    when(() => repository.getPrefs()).thenAnswer(
      (_) async => const Right<Failure, NotificationPrefs>(NotificationPrefs()),
    );
    when(() => repository.getBills('w1', from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => Right<Failure, List<ReminderBill>>([bill]));
    when(() => repository.getInvoices('w1', from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => Right<Failure, List<ReminderInvoice>>([invoice]));
    when(() => scheduler.replaceAll(any()))
        .thenAnswer((invocation) async => (invocation.positionalArguments.first as List).length);
    when(() => scheduler.cancelAll()).thenAnswer((_) async {});
  });

  void stubPrefs(NotificationPrefs prefs) {
    when(() => repository.getPrefs())
        .thenAnswer((_) async => Right<Failure, NotificationPrefs>(prefs));
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(SyncRemindersParams(workspaceId: ' ', now: now));

    expect(result, const Left<Failure, int>(ValidationFailure('invalid_workspace')));
    verifyNever(() => repository.getPrefs());
  });

  test('schedules the reminders of the bills and the invoices', () async {
    final result = await useCase(params);

    // The bill: day before + day of. The invoice: 3 days before + day of.
    expect(result, const Right<Failure, int>(4));
    final captured = verify(() => scheduler.replaceAll(captureAny())).captured.single
        as List<ScheduledReminder>;
    expect(captured.map((r) => r.kind).toSet(), {ReminderKind.bill, ReminderKind.invoice});
  });

  test('asks for the next 30 days, starting today', () async {
    await useCase(params);

    verify(() => repository.getBills(
          'w1',
          from: DateTime(2026, 10, 6),
          to: DateTime(2026, 11, 6),
        )).called(1);
    verify(() => repository.getInvoices(
          'w1',
          from: DateTime(2026, 10, 6),
          to: DateTime(2026, 11, 6),
        )).called(1);
  });

  test('does not look for bills when bill reminders are off', () async {
    stubPrefs(const NotificationPrefs(billReminder: false));

    final result = await useCase(params);

    expect(result, const Right<Failure, int>(2));
    verifyNever(() => repository.getBills(any(), from: any(named: 'from'), to: any(named: 'to')));
  });

  test('does not look for invoices when card reminders are off', () async {
    stubPrefs(const NotificationPrefs(cardDue: false));

    final result = await useCase(params);

    expect(result, const Right<Failure, int>(2));
    verifyNever(() => repository.getInvoices(any(), from: any(named: 'from'), to: any(named: 'to')));
  });

  test('with everything off it cancels what was scheduled and loads nothing', () async {
    stubPrefs(const NotificationPrefs(billReminder: false, cardDue: false));

    final result = await useCase(params);

    expect(result, const Right<Failure, int>(0));
    verify(() => scheduler.cancelAll()).called(1);
    verifyNever(() => scheduler.replaceAll(any()));
    verifyNever(() => repository.getBills(any(), from: any(named: 'from'), to: any(named: 'to')));
  });

  test('replaces the schedule even when there is nothing due', () async {
    when(() => repository.getBills('w1', from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => const Right<Failure, List<ReminderBill>>([]));
    when(() => repository.getInvoices('w1', from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => const Right<Failure, List<ReminderInvoice>>([]));

    final result = await useCase(params);

    expect(result, const Right<Failure, int>(0));
    verify(() => scheduler.replaceAll(const <ScheduledReminder>[])).called(1);
  });

  test('passes a failure reading the preferences through unchanged', () async {
    when(() => repository.getPrefs()).thenAnswer(
      (_) async => const Left<Failure, NotificationPrefs>(NetworkFailure('network_error')),
    );

    final result = await useCase(params);

    expect(result, const Left<Failure, int>(NetworkFailure('network_error')));
    verifyNever(() => scheduler.replaceAll(any()));
  });

  test('passes a failure loading the bills through, and keeps the old schedule', () async {
    when(() => repository.getBills('w1', from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => const Left<Failure, List<ReminderBill>>(NetworkFailure('network_error')));

    final result = await useCase(params);

    expect(result, const Left<Failure, int>(NetworkFailure('network_error')));
    verifyNever(() => scheduler.replaceAll(any()));
  });

  test('passes a failure loading the invoices through', () async {
    when(() => repository.getInvoices('w1', from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => const Left<Failure, List<ReminderInvoice>>(ServerFailure('unknown_error')));

    final result = await useCase(params);

    expect(result, const Left<Failure, int>(ServerFailure('unknown_error')));
  });

  test('a problem with the phone becomes notifications_error', () async {
    when(() => scheduler.replaceAll(any())).thenThrow(StateError('no alarms'));

    final result = await useCase(params);

    expect(result, const Left<Failure, int>(ServerFailure('notifications_error')));
  });

  test('a problem cancelling becomes notifications_error too', () async {
    stubPrefs(const NotificationPrefs(billReminder: false, cardDue: false));
    when(() => scheduler.cancelAll()).thenThrow(StateError('no alarms'));

    final result = await useCase(params);

    expect(result, const Left<Failure, int>(ServerFailure('notifications_error')));
  });
}
