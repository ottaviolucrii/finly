import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:finly/features/audit/domain/repositories/audit_repository.dart';
import 'package:finly/features/audit/domain/usecases/get_audit_history_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements AuditRepository {}

void main() {
  late MockRepository repository;
  late GetAuditHistoryUseCase useCase;

  setUpAll(() => registerFallbackValue(AuditFilter.all));

  setUp(() {
    repository = MockRepository();
    useCase = GetAuditHistoryUseCase(repository);
  });

  AuditRecord record(int n) {
    return AuditRecord(
      id: 'r$n',
      tableName: 'accounts',
      recordId: 'a$n',
      action: AuditAction.insert,
      newData: {'name': 'Conta $n', 'type': 'checking', 'currency': 'BRL'},
      occurredAt: DateTime.utc(2026, 10, 7, 12),
    );
  }

  void stub(
    List<AuditRecord> records, {
    AuditLookup lookup = const AuditLookup(),
  }) {
    when(() => repository.getRecords(
          any(),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
        )).thenAnswer((_) async => Right<Failure, List<AuditRecord>>(records));
    when(() => repository.getLookup(any()))
        .thenAnswer((_) async => Right<Failure, AuditLookup>(lookup));
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(const GetAuditHistoryParams(workspaceId: ' '));

    expect(result, const Left<Failure, AuditPage>(ValidationFailure('invalid_workspace')));
    verifyNever(() => repository.getLookup(any()));
  });

  test('rejects a page that makes no sense', () async {
    for (final params in const [
      GetAuditHistoryParams(workspaceId: 'w1', offset: -1),
      GetAuditHistoryParams(workspaceId: 'w1', limit: 0),
      GetAuditHistoryParams(workspaceId: 'w1', limit: 101),
    ]) {
      final result = await useCase(params);

      expect(result, const Left<Failure, AuditPage>(ValidationFailure('invalid_page')));
    }
  });

  test('asks for the page and the filter it was given', () async {
    stub(const []);

    await useCase(const GetAuditHistoryParams(
      workspaceId: 'w1',
      offset: 30,
      limit: 10,
      filter: AuditFilter.budgets,
    ));

    verify(() => repository.getRecords('w1', offset: 30, limit: 10, filter: AuditFilter.budgets)).called(1);
    verify(() => repository.getLookup('w1')).called(1);
  });

  test('turns the records into sentences', () async {
    stub([record(1), record(2)]);

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1'));

    final page = result.getOrElse(() => throw StateError('expected a page'));
    expect(page.items.map((i) => i.title), ['Conta criada: Conta 1', 'Conta criada: Conta 2']);
  });

  test('uses the names of the lookup', () async {
    when(() => repository.getRecords(any(), offset: any(named: 'offset'), limit: any(named: 'limit'), filter: any(named: 'filter')))
        .thenAnswer((_) async => Right<Failure, List<AuditRecord>>([
              AuditRecord(
                id: 'r1',
                tableName: 'budgets',
                recordId: 'b1',
                action: AuditAction.insert,
                newData: const {'category_id': 'c1', 'limit_cents': 80000, 'currency': 'BRL'},
                occurredAt: DateTime.utc(2026, 10, 7, 12),
              ),
            ]));
    when(() => repository.getLookup(any())).thenAnswer(
      (_) async => const Right<Failure, AuditLookup>(AuditLookup(categoryNames: {'c1': 'Mercado'})),
    );

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1'));

    expect(result.getOrElse(() => throw StateError('x')).items.single.title, 'Orçamento criado: Mercado');
  });

  test('a full page says there may be more', () async {
    stub([for (var i = 0; i < 5; i++) record(i)]);

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1', limit: 5));

    expect(result.getOrElse(() => throw StateError('x')).hasMore, isTrue);
  });

  test('a page that is not full is the last one', () async {
    stub([for (var i = 0; i < 4; i++) record(i)]);

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1', limit: 5));

    expect(result.getOrElse(() => throw StateError('x')).hasMore, isFalse);
  });

  test('no records is an empty page', () async {
    stub(const []);

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1'));

    final page = result.getOrElse(() => throw StateError('x'));
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('a failure reading the records is passed through', () async {
    when(() => repository.getRecords(any(), offset: any(named: 'offset'), limit: any(named: 'limit'), filter: any(named: 'filter')))
        .thenAnswer((_) async => const Left<Failure, List<AuditRecord>>(NetworkFailure('network_error')));
    when(() => repository.getLookup(any()))
        .thenAnswer((_) async => const Right<Failure, AuditLookup>(AuditLookup()));

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1'));

    expect(result, const Left<Failure, AuditPage>(NetworkFailure('network_error')));
  });

  test('a failure reading the names is passed through too', () async {
    when(() => repository.getRecords(any(), offset: any(named: 'offset'), limit: any(named: 'limit'), filter: any(named: 'filter')))
        .thenAnswer((_) async => const Right<Failure, List<AuditRecord>>([]));
    when(() => repository.getLookup(any()))
        .thenAnswer((_) async => const Left<Failure, AuditLookup>(PermissionFailure('forbidden')));

    final result = await useCase(const GetAuditHistoryParams(workspaceId: 'w1'));

    expect(result, const Left<Failure, AuditPage>(PermissionFailure('forbidden')));
  });
}
