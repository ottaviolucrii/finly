import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetInvoices extends Mock implements GetInvoicesUseCase {}

void main() {
  late MockGetInvoices getInvoices;

  final invoice = InvoiceEntity(
    id: 'i1',
    accountId: 'a1',
    referenceMonth: DateTime(2026, 3),
    periodStart: DateTime(2026, 2, 11),
    periodEnd: DateTime(2026, 3, 10),
    dueDate: DateTime(2026, 3, 17),
    status: InvoiceStatus.open,
    totalCents: 10000,
  );

  setUp(() => getInvoices = MockGetInvoices());

  blocTest<InvoicesCubit, InvoicesState>(
    'load emits loading then the invoices',
    build: () {
      when(() => getInvoices('a1')).thenAnswer(
        (_) async => Right<Failure, List<InvoiceEntity>>([invoice]),
      );
      return InvoicesCubit(getInvoices);
    },
    act: (cubit) => cubit.load('a1'),
    expect: () => [
      const InvoicesState(status: InvoicesStatus.loading),
      InvoicesState(status: InvoicesStatus.loaded, invoices: [invoice]),
    ],
  );

  blocTest<InvoicesCubit, InvoicesState>(
    'load emits loading then failure',
    build: () {
      when(() => getInvoices('a1')).thenAnswer(
        (_) async => const Left<Failure, List<InvoiceEntity>>(
          PermissionFailure('forbidden'),
        ),
      );
      return InvoicesCubit(getInvoices);
    },
    act: (cubit) => cubit.load('a1'),
    expect: () => [
      const InvoicesState(status: InvoicesStatus.loading),
      const InvoicesState(
        status: InvoicesStatus.failure,
        failure: PermissionFailure('forbidden'),
      ),
    ],
  );

  blocTest<InvoicesCubit, InvoicesState>(
    'reload loads the same card again',
    build: () {
      when(() => getInvoices('a1')).thenAnswer(
        (_) async => Right<Failure, List<InvoiceEntity>>([invoice]),
      );
      return InvoicesCubit(getInvoices);
    },
    act: (cubit) async {
      await cubit.load('a1');
      await cubit.reload();
    },
    verify: (_) => verify(() => getInvoices('a1')).called(2),
  );
}