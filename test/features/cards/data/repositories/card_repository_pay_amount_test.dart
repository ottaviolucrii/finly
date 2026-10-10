import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/data/repositories/card_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements CardRemoteDataSource {}

void main() {
  late MockRemote remote;
  late CardRepositoryImpl repository;
  final paidAt = DateTime(2026, 3, 12);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = CardRepositoryImpl(remote);
  });

  test('a part is paid with its amount', () async {
    when(() => remote.payInvoice(
          invoiceId: 'i1',
          fromAccountId: 'a2',
          paidAt: paidAt,
          amountCents: 5000,
        )).thenAnswer((_) async => 'tr1');

    final result = await repository.payInvoice(
      invoiceId: 'i1',
      fromAccountId: 'a2',
      paidAt: paidAt,
      amountCents: 5000,
    );

    expect(result, const Right<Failure, String>('tr1'));
  });

  test('with no amount, none is sent to the server', () async {
    when(() => remote.payInvoice(
          invoiceId: 'i1',
          fromAccountId: 'a2',
          paidAt: paidAt,
        )).thenAnswer((_) async => 'tr2');

    final result = await repository.payInvoice(
      invoiceId: 'i1',
      fromAccountId: 'a2',
      paidAt: paidAt,
    );

    expect(result, const Right<Failure, String>('tr2'));
    // The call is the one with no amount (a call with no amount reads as null).
    verify(() => remote.payInvoice(
          invoiceId: 'i1',
          fromAccountId: 'a2',
          paidAt: paidAt,
        )).called(1);
    verifyNever(() => remote.payInvoice(
          invoiceId: any(named: 'invoiceId'),
          fromAccountId: any(named: 'fromAccountId'),
          paidAt: any(named: 'paidAt'),
          amountCents: 1,
        ));
  });

  test('an amount above what is owed becomes a RuleFailure', () async {
    when(() => remote.payInvoice(
          invoiceId: any(named: 'invoiceId'),
          fromAccountId: any(named: 'fromAccountId'),
          paidAt: any(named: 'paidAt'),
          amountCents: any(named: 'amountCents'),
        )).thenThrow(
      PostgrestException(message: 'payment amount is above what is owed', code: '23514'),
    );

    final result = await repository.payInvoice(
      invoiceId: 'i1',
      fromAccountId: 'a2',
      paidAt: paidAt,
      amountCents: 999999,
    );

    expect(result, const Left<Failure, String>(RuleFailure('payment amount is above what is owed')));
  });

  test("another user's invoice becomes PermissionFailure", () async {
    when(() => remote.payInvoice(
          invoiceId: any(named: 'invoiceId'),
          fromAccountId: any(named: 'fromAccountId'),
          paidAt: any(named: 'paidAt'),
          amountCents: any(named: 'amountCents'),
        )).thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

    final result = await repository.payInvoice(
      invoiceId: 'i1',
      fromAccountId: 'a2',
      paidAt: paidAt,
      amountCents: 100,
    );

    expect(result, const Left<Failure, String>(PermissionFailure('forbidden')));
  });
}
