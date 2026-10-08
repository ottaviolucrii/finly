import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/goals/data/datasources/goal_remote_data_source.dart';
import 'package:finly/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:finly/features/goals/domain/entities/goals_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements GoalRemoteDataSource {}

void main() {
  group('goalFromRow', () {
    final row = <String, dynamic>{
      'id': 'g1',
      'workspace_id': 'w1',
      'account_id': 'a1',
      'currency': 'BRL',
      'name': 'Reserva de emergência',
      'target_cents': 500000,
      'target_date': '2027-06-30',
      'archived_at': null,
    };

    test('reads a row of the table', () {
      final goal = goalFromRow(row);

      expect(goal.id, 'g1');
      expect(goal.workspaceId, 'w1');
      expect(goal.accountId, 'a1');
      expect(goal.currency, 'BRL');
      expect(goal.name, 'Reserva de emergência');
      expect(goal.targetCents, 500000);
      expect(goal.targetDate, DateTime(2027, 6, 30));
    });

    test('a goal with no date has none', () {
      expect(goalFromRow({...row, 'target_date': null}).targetDate, isNull);
    });

    test('a number that comes as a decimal is still whole cents', () {
      expect(goalFromRow({...row, 'target_cents': 500000.0}).targetCents, 500000);
    });

    test('the date is a day, with no time zone shift', () {
      final goal = goalFromRow({...row, 'target_date': '2027-01-01'});

      expect(goal.targetDate!.year, 2027);
      expect(goal.targetDate!.month, 1);
      expect(goal.targetDate!.day, 1);
    });

    test('a column that is not what it should be is an error', () {
      expect(() => goalFromRow({...row, 'name': null}), throwsA(isA<TypeError>()));
      expect(() => goalFromRow({...row, 'target_date': 'amanhã'}), throwsFormatException);
    });
  });

  group('GoalRepositoryImpl', () {
    late MockRemote remote;
    late GoalRepositoryImpl repository;

    setUpAll(() => registerFallbackValue(DateTime(2026)));

    setUp(() {
      remote = MockRemote();
      repository = GoalRepositoryImpl(remote);
    });

    test('returns the snapshot the data source read', () async {
      const snapshot = GoalsSnapshot(balances: {'a1': 100});
      when(() => remote.getSnapshot('w1')).thenAnswer((_) async => snapshot);

      final result = await repository.getSnapshot('w1');

      expect(result, const Right<Failure, GoalsSnapshot>(snapshot));
    });

    test('creates a goal through the data source', () async {
      when(() => remote.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async {});

      final result = await repository.createGoal(
        workspaceId: 'w1',
        accountId: 'a1',
        currency: 'BRL',
        name: 'Reserva',
        targetCents: 500000,
        targetDate: DateTime(2027, 6, 30),
      );

      expect(result.isRight(), isTrue);
      verify(() => remote.createGoal(
            workspaceId: 'w1',
            accountId: 'a1',
            currency: 'BRL',
            name: 'Reserva',
            targetCents: 500000,
            targetDate: DateTime(2027, 6, 30),
          )).called(1);
    });

    test('changes a goal through the data source', () async {
      when(() => remote.updateGoal(
            id: any(named: 'id'),
            accountId: any(named: 'accountId'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async {});

      final result = await repository.updateGoal(
        id: 'g1',
        accountId: 'a1',
        name: 'Reserva',
        targetCents: 700000,
      );

      expect(result.isRight(), isTrue);
      verify(() => remote.updateGoal(
            id: 'g1',
            accountId: 'a1',
            name: 'Reserva',
            targetCents: 700000,
            targetDate: null,
          )).called(1);
    });

    test('archives a goal through the data source', () async {
      when(() => remote.archiveGoal('g1')).thenAnswer((_) async {});

      final result = await repository.archiveGoal('g1');

      expect(result.isRight(), isTrue);
    });

    test('a name already used becomes ConflictFailure', () async {
      when(() => remote.archiveGoal(any()))
          .thenThrow(PostgrestException(message: 'duplicate key', code: '23505'));

      final result = await repository.archiveGoal('g1');

      expect(result, const Left<Failure, void>(ConflictFailure('already_exists')));
    });

    test('a credit card refused by the database becomes a RuleFailure with the reason', () async {
      when(() => remote.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenThrow(PostgrestException(message: 'a goal cannot follow a credit card', code: '23514'));

      final result = await repository.createGoal(
        workspaceId: 'w1',
        accountId: 'card',
        currency: 'BRL',
        name: 'Cartão',
        targetCents: 1000,
      );

      expect(result, const Left<Failure, void>(RuleFailure('a goal cannot follow a credit card')));
    });

    test("someone else's workspace becomes PermissionFailure", () async {
      when(() => remote.getSnapshot(any()))
          .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

      final result = await repository.getSnapshot('w1');

      expect(result, const Left<Failure, GoalsSnapshot>(PermissionFailure('forbidden')));
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getSnapshot(any())).thenThrow(TimeoutException('slow'));

      final result = await repository.getSnapshot('w1');

      expect(result, const Left<Failure, GoalsSnapshot>(NetworkFailure('network_error')));
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.getSnapshot(any())).thenThrow(StateError('boom'));

      final result = await repository.getSnapshot('w1');

      expect(result, const Left<Failure, GoalsSnapshot>(ServerFailure('unknown_error')));
    });
  });
}
