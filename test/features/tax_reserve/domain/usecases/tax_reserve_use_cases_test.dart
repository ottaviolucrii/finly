import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/domain/repositories/tax_reserve_repository.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_reserve_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/save_tax_reserve_percent_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements TaxReserveRepository {}

void main() {
  late MockRepository repository;

  const data = TaxReserveData(
    percentBps: 650,
    currency: 'BRL',
    incomeCents: 500000,
    taxCents: 12000,
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockRepository());

  group('GetTaxReserveUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetTaxReserveUseCase(repository)(
        GetTaxReserveParams(workspaceId: ' ', month: DateTime(2026, 10)),
      );

      expect(result, const Left<Failure, TaxReserveData>(ValidationFailure('invalid_workspace')));
      verifyNever(() => repository.getData(any(), any()));
    });

    test('asks for the first day of the month', () async {
      when(() => repository.getData('w1', DateTime(2026, 10)))
          .thenAnswer((_) async => const Right<Failure, TaxReserveData>(data));

      final result = await GetTaxReserveUseCase(repository)(
        GetTaxReserveParams(workspaceId: 'w1', month: DateTime(2026, 10, 17, 14)),
      );

      expect(result, const Right<Failure, TaxReserveData>(data));
      verify(() => repository.getData('w1', DateTime(2026, 10))).called(1);
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.getData(any(), any())).thenAnswer(
        (_) async => const Left<Failure, TaxReserveData>(NetworkFailure('network_error')),
      );

      final result = await GetTaxReserveUseCase(repository)(
        GetTaxReserveParams(workspaceId: 'w1', month: DateTime(2026, 10)),
      );

      expect(result, const Left<Failure, TaxReserveData>(NetworkFailure('network_error')));
    });
  });

  group('SaveTaxReservePercentUseCase', () {
    SaveTaxReservePercentUseCase build() => SaveTaxReservePercentUseCase(repository);

    test('rejects an empty workspace id', () async {
      final result = await build()(
        const SaveTaxReservePercentParams(workspaceId: '', percentBps: 650),
      );

      expect(result, const Left<Failure, void>(ValidationFailure('invalid_workspace')));
      verifyNever(() => repository.savePercent(any(), any()));
    });

    test('rejects a negative percentage', () async {
      final result = await build()(
        const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: -1),
      );

      expect(result, const Left<Failure, void>(ValidationFailure('invalid_percent')));
      verifyNever(() => repository.savePercent(any(), any()));
    });

    test('rejects more than 100%', () async {
      final result = await build()(
        const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 10001),
      );

      expect(result, const Left<Failure, void>(ValidationFailure('invalid_percent')));
    });

    test('accepts 0% and 100%', () async {
      when(() => repository.savePercent(any(), any()))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final zero = await build()(const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 0));
      final all = await build()(const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 10000));

      expect(zero.isRight(), isTrue);
      expect(all.isRight(), isTrue);
    });

    test('forwards the percentage to the repository', () async {
      when(() => repository.savePercent('w1', 650))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      await build()(const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 650));

      verify(() => repository.savePercent('w1', 650)).called(1);
    });

    test('passes the refusal of the database through unchanged', () async {
      when(() => repository.savePercent(any(), any())).thenAnswer(
        (_) async => const Left<Failure, void>(RuleFailure('new row violates check constraint')),
      );

      final result = await build()(
        const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 650),
      );

      expect(result, const Left<Failure, void>(RuleFailure('new row violates check constraint')));
    });
  });
}
