import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/domain/usecases/get_audit_history_use_case.dart';
import 'package:finly/features/audit/presentation/cubit/audit_cubit.dart';
import 'package:finly/features/audit/presentation/cubit/audit_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetHistory extends Mock implements GetAuditHistoryUseCase {}

void main() {
  late MockGetHistory getHistory;

  AuditItem item(int n) {
    return AuditItem(
      id: 'r$n',
      tableName: 'transactions',
      kind: AuditKind.created,
      title: 'Saída criada: $n',
      summary: '',
      changes: const [],
      occurredAt: DateTime(2026, 10, 7, 12),
    );
  }

  AuditPage page(List<int> numbers, {bool hasMore = false}) {
    return AuditPage(items: [for (final n in numbers) item(n)], hasMore: hasMore);
  }

  setUpAll(() => registerFallbackValue(const GetAuditHistoryParams(workspaceId: 'w1')));

  setUp(() => getHistory = MockGetHistory());

  GetAuditHistoryParams params({int offset = 0, AuditFilter filter = AuditFilter.all}) {
    return GetAuditHistoryParams(workspaceId: 'w1', offset: offset, filter: filter);
  }

  void stub(GetAuditHistoryParams p, AuditPage result) {
    when(() => getHistory(p)).thenAnswer((_) async => Right<Failure, AuditPage>(result));
  }

  AuditCubit build() => AuditCubit(getHistory);

  test('starts loading, with nothing on screen', () {
    final cubit = build();

    expect(cubit.state.status, AuditStatus.loading);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.filter, AuditFilter.all);
    cubit.close();
  });

  test('load shows the first page', () async {
    stub(params(), page([1, 2, 3], hasMore: true));
    final cubit = build();

    await cubit.load('w1');

    expect(cubit.state.status, AuditStatus.loaded);
    expect(cubit.state.items.map((i) => i.id), ['r1', 'r2', 'r3']);
    expect(cubit.state.hasMore, isTrue);
    await cubit.close();
  });

  test('a failure with nothing to show is reported', () async {
    when(() => getHistory(any())).thenAnswer(
      (_) async => const Left<Failure, AuditPage>(NetworkFailure('network_error')),
    );
    final cubit = build();

    await cubit.load('w1');

    expect(cubit.state.status, AuditStatus.failure);
    expect(cubit.state.failure, const NetworkFailure('network_error'));
    expect(cubit.state.items, isEmpty);
    await cubit.close();
  });

  test('refresh before the first load does nothing', () async {
    final cubit = build();

    await cubit.refresh();

    verifyNever(() => getHistory(any()));
    await cubit.close();
  });

  test('refresh keeps the list on screen while it reads again', () async {
    stub(params(), page([1, 2]));
    final cubit = build();
    await cubit.load('w1');
    final gate = Completer<Either<Failure, AuditPage>>();
    when(() => getHistory(params())).thenAnswer((_) => gate.future);

    final refreshing = cubit.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, AuditStatus.loading);
    expect(cubit.state.items, hasLength(2));

    gate.complete(Right<Failure, AuditPage>(page([5, 4, 3, 2, 1])));
    await refreshing;

    expect(cubit.state.items, hasLength(5));
    await cubit.close();
  });

  test('another filter starts with an empty list and shows its own page', () async {
    stub(params(), page([1, 2]));
    stub(params(filter: AuditFilter.budgets), page([9]));
    final cubit = build();
    await cubit.load('w1');
    final gate = Completer<Either<Failure, AuditPage>>();
    when(() => getHistory(params(filter: AuditFilter.accounts))).thenAnswer((_) => gate.future);

    final changing = cubit.setFilter(AuditFilter.accounts);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.filter, AuditFilter.accounts);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.status, AuditStatus.loading);

    gate.complete(Right<Failure, AuditPage>(page([7])));
    await changing;

    expect(cubit.state.items.single.id, 'r7');
    await cubit.close();
  });

  test('choosing the filter that is already shown does nothing', () async {
    stub(params(), page([1]));
    final cubit = build();
    await cubit.load('w1');
    clearInteractions(getHistory);

    await cubit.setFilter(AuditFilter.all);

    verifyNever(() => getHistory(any()));
    await cubit.close();
  });

  group('loadMore', () {
    test('adds the next page below, starting after what is shown', () async {
      stub(params(), page([1, 2], hasMore: true));
      stub(params(offset: 2), page([3, 4]));
      final cubit = build();
      await cubit.load('w1');

      await cubit.loadMore();

      expect(cubit.state.items.map((i) => i.id), ['r1', 'r2', 'r3', 'r4']);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.loadingMore, isFalse);
      verify(() => getHistory(params(offset: 2))).called(1);
      await cubit.close();
    });

    test('asks for the page of the filter on screen', () async {
      stub(params(), page([]));
      stub(params(filter: AuditFilter.budgets), page([1], hasMore: true));
      stub(params(offset: 1, filter: AuditFilter.budgets), page([2]));
      final cubit = build();
      await cubit.load('w1');
      await cubit.setFilter(AuditFilter.budgets);

      await cubit.loadMore();

      expect(cubit.state.items.map((i) => i.id), ['r1', 'r2']);
      await cubit.close();
    });

    test('says it is loading while it reads', () async {
      stub(params(), page([1], hasMore: true));
      final gate = Completer<Either<Failure, AuditPage>>();
      when(() => getHistory(params(offset: 1))).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final loading = cubit.loadMore();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.loadingMore, isTrue);
      expect(cubit.state.items, hasLength(1));

      gate.complete(Right<Failure, AuditPage>(page([2])));
      await loading;
      expect(cubit.state.loadingMore, isFalse);
      await cubit.close();
    });

    test('does nothing when there is no more', () async {
      stub(params(), page([1]));
      final cubit = build();
      await cubit.load('w1');
      clearInteractions(getHistory);

      await cubit.loadMore();

      verifyNever(() => getHistory(any()));
      await cubit.close();
    });

    test('a second request while one is running is ignored', () async {
      stub(params(), page([1], hasMore: true));
      final gate = Completer<Either<Failure, AuditPage>>();
      when(() => getHistory(params(offset: 1))).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final first = cubit.loadMore();
      await Future<void>.delayed(Duration.zero);
      await cubit.loadMore();
      gate.complete(Right<Failure, AuditPage>(page([2])));
      await first;

      verify(() => getHistory(params(offset: 1))).called(1);
      await cubit.close();
    });

    test('a failure keeps what is on screen, and says so', () async {
      stub(params(), page([1, 2], hasMore: true));
      when(() => getHistory(params(offset: 2))).thenAnswer(
        (_) async => const Left<Failure, AuditPage>(NetworkFailure('network_error')),
      );
      final cubit = build();
      await cubit.load('w1');

      await cubit.loadMore();

      expect(cubit.state.status, AuditStatus.loaded);
      expect(cubit.state.items, hasLength(2));
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.failure, const NetworkFailure('network_error'));
      expect(cubit.state.loadingMore, isFalse);
      await cubit.close();
    });
  });

  test('a slow answer for a filter the person left never replaces the newer list', () async {
    final slow = Completer<Either<Failure, AuditPage>>();
    when(() => getHistory(params())).thenAnswer((_) => slow.future);
    stub(params(filter: AuditFilter.budgets), page([9]));
    final cubit = build();

    final first = cubit.load('w1');
    await cubit.setFilter(AuditFilter.budgets);
    slow.complete(Right<Failure, AuditPage>(page([1, 2, 3])));
    await first;

    expect(cubit.state.filter, AuditFilter.budgets);
    expect(cubit.state.items.single.id, 'r9');
    await cubit.close();
  });
}
