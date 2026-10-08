import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/entities/goals_snapshot.dart';
import 'package:finly/features/goals/domain/repositories/goal_repository.dart';
import 'package:finly/features/goals/domain/usecases/archive_goal_use_case.dart';
import 'package:finly/features/goals/domain/usecases/get_goal_progress_use_case.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements GoalRepository {}

void main() {
  late MockRepository repository;

  final today = DateTime(2026, 10, 7, 14);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockRepository());

  Goal goal(String id, String name, {String account = 'a1', DateTime? date}) {
    return Goal(
      id: id,
      workspaceId: 'w1',
      accountId: account,
      currency: 'BRL',
      name: name,
      targetCents: 500000,
      targetDate: date,
    );
  }

  group('GetGoalProgressUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetGoalProgressUseCase(repository)(
        GetGoalProgressParams(workspaceId: ' ', today: today),
      );

      expect(result, const Left<Failure, List<GoalProgress>>(ValidationFailure('invalid_workspace')));
      verifyNever(() => repository.getSnapshot(any()));
    });

    test('puts the balance and the name of the account on each goal', () async {
      when(() => repository.getSnapshot('w1')).thenAnswer(
        (_) async => Right<Failure, GoalsSnapshot>(
          GoalsSnapshot(
            goals: [goal('g1', 'Reserva'), goal('g2', 'Viagem', account: 'a2')],
            balances: const {'a1': 125000, 'a2': 40000},
            accountNames: const {'a1': 'Poupança', 'a2': 'Carteira'},
          ),
        ),
      );

      final result = await GetGoalProgressUseCase(repository)(
        GetGoalProgressParams(workspaceId: 'w1', today: today),
      );

      final items = result.getOrElse(() => throw StateError('expected goals'));
      final byName = {for (final item in items) item.goal.name: item};
      expect(byName['Reserva']!.balanceCents, 125000);
      expect(byName['Reserva']!.accountName, 'Poupança');
      expect(byName['Viagem']!.balanceCents, 40000);
      expect(byName['Viagem']!.accountName, 'Carteira');
    });

    test('an account with no balance row has saved nothing', () async {
      when(() => repository.getSnapshot(any())).thenAnswer(
        (_) async => Right<Failure, GoalsSnapshot>(GoalsSnapshot(goals: [goal('g1', 'Reserva')])),
      );

      final result = await GetGoalProgressUseCase(repository)(
        GetGoalProgressParams(workspaceId: 'w1', today: today),
      );

      final item = result.getOrElse(() => throw StateError('x')).single;
      expect(item.balanceCents, 0);
      expect(item.accountName, isEmpty);
    });

    test('puts the goals in the order of the screen', () async {
      when(() => repository.getSnapshot(any())).thenAnswer(
        (_) async => Right<Failure, GoalsSnapshot>(
          GoalsSnapshot(
            goals: [
              goal('g1', 'Sem prazo'),
              goal('g2', 'Com prazo', date: DateTime(2027, 1, 1)),
              goal('g3', 'Outra sem prazo'),
            ],
            balances: const {'a1': 0},
          ),
        ),
      );

      final result = await GetGoalProgressUseCase(repository)(
        GetGoalProgressParams(workspaceId: 'w1', today: today),
      );

      final names = result.getOrElse(() => throw StateError('x')).map((i) => i.goal.name).toList();
      expect(names.first, 'Com prazo');
    });

    test('no goals is an empty list', () async {
      when(() => repository.getSnapshot(any()))
          .thenAnswer((_) async => const Right<Failure, GoalsSnapshot>(GoalsSnapshot()));

      final result = await GetGoalProgressUseCase(repository)(
        GetGoalProgressParams(workspaceId: 'w1', today: today),
      );

      expect(result.getOrElse(() => throw StateError('x')), isEmpty);
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.getSnapshot(any())).thenAnswer(
        (_) async => const Left<Failure, GoalsSnapshot>(NetworkFailure('network_error')),
      );

      final result = await GetGoalProgressUseCase(repository)(
        GetGoalProgressParams(workspaceId: 'w1', today: today),
      );

      expect(result, const Left<Failure, List<GoalProgress>>(NetworkFailure('network_error')));
    });
  });

  group('SaveGoalUseCase', () {
    SaveGoalUseCase build() => SaveGoalUseCase(repository);

    SaveGoalParams params({
      String? id,
      String workspaceId = 'w1',
      String accountId = 'a1',
      String currency = 'BRL',
      String name = 'Reserva',
      int target = 500000,
      DateTime? date,
    }) {
      return SaveGoalParams(
        id: id,
        workspaceId: workspaceId,
        accountId: accountId,
        currency: currency,
        name: name,
        targetCents: target,
        targetDate: date,
      );
    }

    void verifyNothingSaved() {
      verifyNever(() => repository.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          ));
      verifyNever(() => repository.updateGoal(
            id: any(named: 'id'),
            accountId: any(named: 'accountId'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          ));
    }

    Future<void> expectRejected(SaveGoalParams value, String code) async {
      final result = await build()(value);

      expect(result, Left<Failure, void>(ValidationFailure(code)));
      verifyNothingSaved();
    }

    test('rejects an empty workspace', () => expectRejected(params(workspaceId: ' '), 'invalid_workspace'));

    test('rejects an empty account', () => expectRejected(params(accountId: ''), 'invalid_account'));

    test('rejects an empty name or one with only spaces', () async {
      await expectRejected(params(name: ''), 'invalid_name');
      await expectRejected(params(name: '   '), 'invalid_name');
    });

    test('rejects a name longer than 80 characters', () async {
      await expectRejected(params(name: 'a' * 81), 'invalid_name');
    });

    test('accepts a name of exactly 80 characters', () async {
      when(() => repository.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await build()(params(name: 'a' * 80));

      expect(result.isRight(), isTrue);
    });

    test('rejects a target that is zero, negative or too big', () async {
      await expectRejected(params(target: 0), 'invalid_target');
      await expectRejected(params(target: -100), 'invalid_target');
      await expectRejected(params(target: SaveGoalUseCase.maxTargetCents + 1), 'invalid_target');
    });

    test('rejects a currency that is not three capital letters', () async {
      await expectRejected(params(currency: 'brl'), 'invalid_currency');
      await expectRejected(params(currency: 'BRLX'), 'invalid_currency');
      await expectRejected(params(currency: ''), 'invalid_currency');
    });

    test('creates a goal with the name trimmed and the date as given', () async {
      when(() => repository.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await build()(params(name: '  Reserva  ', date: DateTime(2027, 6, 30)));

      expect(result.isRight(), isTrue);
      verify(() => repository.createGoal(
            workspaceId: 'w1',
            accountId: 'a1',
            currency: 'BRL',
            name: 'Reserva',
            targetCents: 500000,
            targetDate: DateTime(2027, 6, 30),
          )).called(1);
    });

    test('changes a goal when it has an id, and a missing date removes it', () async {
      when(() => repository.updateGoal(
            id: any(named: 'id'),
            accountId: any(named: 'accountId'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await build()(params(id: 'g1', name: ' Nova ', target: 700000));

      expect(result.isRight(), isTrue);
      verify(() => repository.updateGoal(
            id: 'g1',
            accountId: 'a1',
            name: 'Nova',
            targetCents: 700000,
            targetDate: null,
          )).called(1);
      verifyNever(() => repository.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          ));
    });

    test('passes a refusal of the database through unchanged', () async {
      when(() => repository.createGoal(
            workspaceId: any(named: 'workspaceId'),
            accountId: any(named: 'accountId'),
            currency: any(named: 'currency'),
            name: any(named: 'name'),
            targetCents: any(named: 'targetCents'),
            targetDate: any(named: 'targetDate'),
          )).thenAnswer((_) async => const Left<Failure, void>(ConflictFailure('already_exists')));

      final result = await build()(params());

      expect(result, const Left<Failure, void>(ConflictFailure('already_exists')));
    });
  });

  group('ArchiveGoalUseCase', () {
    test('rejects an empty id', () async {
      final result = await ArchiveGoalUseCase(repository)('  ');

      expect(result, const Left<Failure, void>(ValidationFailure('invalid_goal')));
      verifyNever(() => repository.archiveGoal(any()));
    });

    test('archives the goal', () async {
      when(() => repository.archiveGoal('g1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await ArchiveGoalUseCase(repository)('g1');

      expect(result.isRight(), isTrue);
      verify(() => repository.archiveGoal('g1')).called(1);
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.archiveGoal(any()))
          .thenAnswer((_) async => const Left<Failure, void>(PermissionFailure('forbidden')));

      final result = await ArchiveGoalUseCase(repository)('g1');

      expect(result, const Left<Failure, void>(PermissionFailure('forbidden')));
    });
  });
}
