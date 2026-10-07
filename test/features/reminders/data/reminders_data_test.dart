import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reminders/data/datasources/reminders_remote_data_source.dart';
import 'package:finly/features/reminders/data/models/notification_prefs_model.dart';
import 'package:finly/features/reminders/data/models/reminder_bill_model.dart';
import 'package:finly/features/reminders/data/models/reminder_invoice_model.dart';
import 'package:finly/features/reminders/data/repositories/reminders_repository_impl.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements RemindersRemoteDataSource {}

void main() {
  group('NotificationPrefsModel', () {
    test('reads the switches and keeps every key', () {
      final model = NotificationPrefsModel.fromMap({
        'bill_reminder': false,
        'card_due': true,
        'budget_alert': true,
      });

      expect(model.billReminder, isFalse);
      expect(model.cardDue, isTrue);
      expect(model.raw['budget_alert'], isTrue);
    });

    test('an empty object means everything on', () {
      final model = NotificationPrefsModel.fromMap({});

      expect(model.billReminder, isTrue);
      expect(model.cardDue, isTrue);
    });
  });

  group('ReminderBillModel', () {
    Map<String, dynamic> row({Object? embedded, String occurredAt = '2026-10-09T15:00:00+00:00'}) {
      return {
        'id': 'b1',
        'description': 'Aluguel',
        'amount_cents': 150000,
        'currency': 'BRL',
        'occurred_at': occurredAt,
        'recurring_transactions': embedded,
      };
    }

    test('reads the bill', () {
      final model = ReminderBillModel.fromMap(row());

      expect(model.id, 'b1');
      expect(model.description, 'Aluguel');
      expect(model.amountCents, 150000);
      expect(model.currency, 'BRL');
      expect(model.dueDate, DateTime(2026, 10, 9));
    });

    test('the due date has no time of day', () {
      final model = ReminderBillModel.fromMap(row());

      expect(model.dueDate.hour, 0);
      expect(model.dueDate.minute, 0);
    });

    test('a bill that does not come from a recurring item has no lead days', () {
      expect(ReminderBillModel.fromMap(row()).leadDays, isNull);
    });

    test('takes the lead days of the recurring item it comes from', () {
      final model = ReminderBillModel.fromMap(row(embedded: {'lead_days': 5}));

      expect(model.leadDays, 5);
    });

    test('also reads the lead days when the embed arrives as a list', () {
      final model = ReminderBillModel.fromMap(
        row(embedded: [
          {'lead_days': 2},
        ]),
      );

      expect(model.leadDays, 2);
    });

    test('an empty list or an object without the column means no lead days', () {
      expect(ReminderBillModel.fromMap(row(embedded: <Object>[])).leadDays, isNull);
      expect(ReminderBillModel.fromMap(row(embedded: <String, dynamic>{})).leadDays, isNull);
    });

    test('reads an amount that arrives as a double', () {
      final map = row()..['amount_cents'] = 150000.0;

      expect(ReminderBillModel.fromMap(map).amountCents, 150000);
    });
  });

  group('ReminderInvoiceModel', () {
    test('parses the date the database writes, with no time zone', () {
      expect(ReminderInvoiceModel.parseDate('2026-10-17'), DateTime(2026, 10, 17));
      expect(ReminderInvoiceModel.parseDate('2026-01-05'), DateTime(2026, 1, 5));
    });

    test('puts together the invoice, its card and its total', () {
      final model = ReminderInvoiceModel.fromParts(
        invoice: {'id': 'i1', 'account_id': 'a1', 'due_date': '2026-10-17'},
        card: {'id': 'a1', 'name': 'Nubank', 'currency': 'BRL'},
        totalCents: 80050,
      );

      expect(model.id, 'i1');
      expect(model.cardName, 'Nubank');
      expect(model.totalCents, 80050);
      expect(model.currency, 'BRL');
      expect(model.dueDate, DateTime(2026, 10, 17));
    });
  });

  group('RemindersRepositoryImpl', () {
    late MockRemote remote;
    late RemindersRepositoryImpl repository;

    final from = DateTime(2026, 10, 6);
    final to = DateTime(2026, 11, 6);

    setUpAll(() {
      registerFallbackValue(const NotificationPrefs());
      registerFallbackValue(DateTime(2026));
    });

    setUp(() {
      remote = MockRemote();
      repository = RemindersRepositoryImpl(remote);
    });

    test('getPrefs returns the preferences from the data source', () async {
      const model = NotificationPrefsModel(billReminder: false);
      when(() => remote.getPrefs()).thenAnswer((_) async => model);

      final result = await repository.getPrefs();

      expect(result, const Right<Failure, NotificationPrefs>(model));
    });

    test('savePrefs sends the preferences to the data source', () async {
      when(() => remote.savePrefs(any())).thenAnswer((_) async {});
      const prefs = NotificationPrefs(cardDue: false);

      final result = await repository.savePrefs(prefs);

      expect(result.isRight(), isTrue);
      verify(() => remote.savePrefs(prefs)).called(1);
    });

    test('getBills returns the bills from the data source', () async {
      final bill = ReminderBillModel(
        id: 'b1',
        description: 'Aluguel',
        amountCents: 150000,
        currency: 'BRL',
        dueDate: DateTime(2026, 10, 9),
      );
      when(() => remote.getBills('w1', from: from, to: to)).thenAnswer((_) async => [bill]);

      final result = await repository.getBills('w1', from: from, to: to);

      result.fold(
        (failure) => fail('expected bills, got $failure'),
        (bills) => expect(bills, <ReminderBill>[bill]),
      );
    });

    test('getInvoices returns the invoices from the data source', () async {
      final invoice = ReminderInvoiceModel(
        id: 'i1',
        cardName: 'Nubank',
        totalCents: 80000,
        currency: 'BRL',
        dueDate: DateTime(2026, 10, 17),
      );
      when(() => remote.getInvoices('w1', from: from, to: to)).thenAnswer((_) async => [invoice]);

      final result = await repository.getInvoices('w1', from: from, to: to);

      result.fold(
        (failure) => fail('expected invoices, got $failure'),
        (invoices) => expect(invoices, <ReminderInvoice>[invoice]),
      );
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getBills(any(), from: any(named: 'from'), to: any(named: 'to')))
          .thenThrow(TimeoutException('slow'));

      final result = await repository.getBills('w1', from: from, to: to);

      expect(
        result,
        const Left<Failure, List<ReminderBill>>(NetworkFailure('network_error')),
      );
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.getPrefs()).thenThrow(StateError('boom'));

      final result = await repository.getPrefs();

      expect(result, const Left<Failure, NotificationPrefs>(ServerFailure('unknown_error')));
    });
  });
}
