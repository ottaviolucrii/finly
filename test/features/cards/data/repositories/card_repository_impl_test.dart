import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/data/models/credit_card_model.dart';
import 'package:finly/features/cards/data/models/invoice_model.dart';
import 'package:finly/features/cards/data/repositories/card_repository_impl.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements CardRemoteDataSource {}

void main() {
  late MockRemote remote;
  late CardRepositoryImpl repository;

  final paidAt = DateTime(2026, 3, 12, 12);

  const cardModel = CreditCardModel(
    accountId: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    currency: 'BRL',
    limitCents: 500000,
    closingDay: 10,
    dueDay: 17,
    usedCents: 0,
  );
  final invoiceModel = InvoiceModel(
    id: 'i1',
    accountId: 'a1',
    referenceMonth: DateTime(2026, 3),
    periodStart: DateTime(2026, 2, 11),
    periodEnd: DateTime(2026, 3, 10),
    dueDate: DateTime(2026, 3, 17),
    status: InvoiceStatus.closed,
    totalCents: 10000,
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = CardRepositoryImpl(remote);
  });

  test('getCards returns the cards', () async {
    when(() => remote.getCards('w1')).thenAnswer((_) async => [cardModel]);

    final result = await repository.getCards('w1');

    result.fold(
      (failure) => fail('expected cards, got $failure'),
      (cards) => expect(cards, [cardModel]),
    );
  });

  test('createCard returns the account id of the new card', () async {
    when(() => remote.createCard(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          currency: any(named: 'currency'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenAnswer((_) async => 'a1');

    final result = await repository.createCard(
      workspaceId: 'w1',
      name: 'Nubank',
      currency: 'BRL',
      limitCents: 500000,
      closingDay: 10,
      dueDay: 17,
    );

    expect(result, const Right<Failure, String>('a1'));
  });

  test('getInvoices returns the invoices', () async {
    when(() => remote.getInvoices('a1'))
        .thenAnswer((_) async => [invoiceModel]);

    final result = await repository.getInvoices('a1');

    result.fold(
      (failure) => fail('expected invoices, got $failure'),
      (invoices) => expect(invoices, <InvoiceEntity>[invoiceModel]),
    );
  });

  test('getInvoiceTransactions returns what the data source returns', () async {
    when(() => remote.getInvoiceTransactions('i1')).thenAnswer((_) async => []);

    final result = await repository.getInvoiceTransactions('i1');

    result.fold(
      (failure) => fail('expected a list, got $failure'),
      (transactions) => expect(transactions, isEmpty),
    );
  });

  test('createInstallments returns the group id', () async {
    when(() => remote.createInstallments(
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          totalCents: any(named: 'totalCents'),
          installments: any(named: 'installments'),
          description: any(named: 'description'),
          purchaseAt: any(named: 'purchaseAt'),
        )).thenAnswer((_) async => 'g1');

    final result = await repository.createInstallments(
      accountId: 'a1',
      totalCents: 100001,
      installments: 3,
      description: 'TV',
      purchaseAt: paidAt,
    );

    expect(result, const Right<Failure, String>('g1'));
  });

  test('paying an invoice twice becomes RuleFailure', () async {
    when(() => remote.payInvoice(
          invoiceId: any(named: 'invoiceId'),
          fromAccountId: any(named: 'fromAccountId'),
          paidAt: any(named: 'paidAt'),
        )).thenThrow(
      PostgrestException(message: 'invoice already paid', code: 'P0001'),
    );

    final result = await repository.payInvoice(
      invoiceId: 'i1',
      fromAccountId: 'a2',
      paidAt: paidAt,
    );

    expect(
      result,
      const Left<Failure, String>(RuleFailure('invoice already paid')),
    );
  });

  test('another user\'s card becomes PermissionFailure', () async {
    when(() => remote.createInstallments(
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          totalCents: any(named: 'totalCents'),
          installments: any(named: 'installments'),
          description: any(named: 'description'),
          purchaseAt: any(named: 'purchaseAt'),
        )).thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

    final result = await repository.createInstallments(
      accountId: 'a1',
      totalCents: 100001,
      installments: 3,
      description: 'TV',
      purchaseAt: paidAt,
    );

    expect(
      result,
      const Left<Failure, String>(PermissionFailure('forbidden')),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getCards('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getCards('w1');

    expect(
      result.isLeft(),
      isTrue,
    );
    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}