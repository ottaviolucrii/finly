import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/usecases/archive_goal_use_case.dart';
import 'package:finly/features/goals/domain/usecases/get_goal_progress_use_case.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_state.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetProgress extends Mock implements GetGoalProgressUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockSave extends Mock implements SaveGoalUseCase {}

class MockArchive extends Mock implements ArchiveGoalUseCase {}

void main() {
  const saveParams = SaveGoalParams(
    workspaceId: 'w1',
    accountId: 'a1',
    currency: 'BRL',
    name: 'Reserva',
    targetCents: 500000,
  );

  setUpAll(() {
    registerFallbackValue(GetGoalProgressParams(workspaceId: 'w1', today: DateTime(2026)));
    registerFallbackValue(saveParams);
  });

  group('GoalsCubit', () {
    late MockGetProgress getProgress;

    final now = DateTime(2026, 10, 7, 14, 30);

    final item = GoalProgress(
      goal: const Goal(
        id: 'g1',
        workspaceId: 'w1',
        accountId: 'a1',
        currency: 'BRL',
        name: 'Reserva',
        targetCents: 500000,
      ),
      accountName: 'Poupança',
      balanceCents: 125000,
    );

    setUp(() => getProgress = MockGetProgress());

    GoalsCubit build() => GoalsCubit(getProgress, clock: () => now);

    test('starts loading, with nothing on screen', () {
      final cubit = build();

      expect(cubit.state.status, GoalsStatus.loading);
      expect(cubit.state.items, isEmpty);
      cubit.close();
    });

    test('load shows the goals, with today as a date', () async {
      when(() => getProgress(any()))
          .thenAnswer((_) async => Right<Failure, List<GoalProgress>>([item]));
      final cubit = build();

      await cubit.load('w1');

      expect(cubit.state.status, GoalsStatus.loaded);
      expect(cubit.state.items, [item]);
      expect(cubit.state.today, DateTime(2026, 10, 7));
      verify(() => getProgress(GetGoalProgressParams(workspaceId: 'w1', today: now))).called(1);
      await cubit.close();
    });

    test('a failure with nothing to show is reported', () async {
      when(() => getProgress(any())).thenAnswer(
        (_) async => const Left<Failure, List<GoalProgress>>(NetworkFailure('network_error')),
      );
      final cubit = build();

      await cubit.load('w1');

      expect(cubit.state.status, GoalsStatus.failure);
      expect(cubit.state.failure, const NetworkFailure('network_error'));
      expect(cubit.state.items, isEmpty);
      await cubit.close();
    });

    test('reload before the first load does nothing', () async {
      final cubit = build();

      await cubit.reload();

      verifyNever(() => getProgress(any()));
      await cubit.close();
    });

    test('reload keeps the goals on screen while it reads again, and when it fails', () async {
      when(() => getProgress(any()))
          .thenAnswer((_) async => Right<Failure, List<GoalProgress>>([item]));
      final cubit = build();
      await cubit.load('w1');

      final gate = Completer<Either<Failure, List<GoalProgress>>>();
      when(() => getProgress(any())).thenAnswer((_) => gate.future);
      final reloading = cubit.reload();

      expect(cubit.state.status, GoalsStatus.loading);
      expect(cubit.state.items, [item]);

      gate.complete(const Left<Failure, List<GoalProgress>>(NetworkFailure('network_error')));
      await reloading;

      expect(cubit.state.status, GoalsStatus.failure);
      expect(cubit.state.items, [item]);
      await cubit.close();
    });
  });

  group('GoalFormCubit', () {
    late MockGetAccounts getAccounts;
    late MockSave saveGoal;
    late MockArchive archiveGoal;

    AccountEntity account(String id, String name, AccountType type, {String currency = 'BRL'}) {
      return AccountEntity(
        id: id,
        workspaceId: 'w1',
        name: name,
        type: type,
        currency: currency,
        openingBalanceCents: 0,
        postedBalanceCents: 0,
        projectedBalanceCents: 0,
      );
    }

    setUp(() {
      getAccounts = MockGetAccounts();
      saveGoal = MockSave();
      archiveGoal = MockArchive();
    });

    GoalFormCubit build() => GoalFormCubit(
          getAccounts: getAccounts,
          saveGoal: saveGoal,
          archiveGoal: archiveGoal,
        );

    test('load keeps the accounts a goal can follow, never a credit card', () async {
      when(() => getAccounts('w1')).thenAnswer(
        (_) async => Right<Failure, List<AccountEntity>>([
          account('a1', 'Nubank', AccountType.checking),
          account('a2', 'Poupança', AccountType.savings),
          account('a3', 'Visa', AccountType.creditCard),
          account('a4', 'Ações', AccountType.investment),
        ]),
      );
      final cubit = build();

      await cubit.load('w1');

      expect(cubit.state.status, GoalFormStatus.ready);
      expect(cubit.state.accounts.map((a) => a.name), ['Nubank', 'Poupança', 'Ações']);
      await cubit.close();
    });

    test('load that fails says so', () async {
      when(() => getAccounts(any())).thenAnswer(
        (_) async => const Left<Failure, List<AccountEntity>>(NetworkFailure('network_error')),
      );
      final cubit = build();

      await cubit.load('w1');

      expect(cubit.state.status, GoalFormStatus.loadFailed);
      expect(cubit.state.loadFailure, const NetworkFailure('network_error'));
      await cubit.close();
    });

    test('a saved goal closes the form', () async {
      when(() => getAccounts(any())).thenAnswer(
        (_) async => Right<Failure, List<AccountEntity>>([account('a1', 'Nubank', AccountType.checking)]),
      );
      final gate = Completer<Either<Failure, void>>();
      when(() => saveGoal(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final saving = cubit.save(saveParams);

      expect(cubit.state.status, GoalFormStatus.saving);
      expect(cubit.state.accounts, hasLength(1));

      gate.complete(const Right<Failure, void>(null));
      await saving;

      expect(cubit.state.status, GoalFormStatus.saved);
      await cubit.close();
    });

    test('a refused save keeps the form open and says why', () async {
      when(() => getAccounts(any())).thenAnswer(
        (_) async => Right<Failure, List<AccountEntity>>([account('a1', 'Nubank', AccountType.checking)]),
      );
      when(() => saveGoal(any()))
          .thenAnswer((_) async => const Left<Failure, void>(ConflictFailure('already_exists')));
      final cubit = build();
      await cubit.load('w1');

      await cubit.save(saveParams);

      expect(cubit.state.status, GoalFormStatus.ready);
      expect(cubit.state.saveFailure, const ConflictFailure('already_exists'));
      expect(cubit.state.accounts, hasLength(1));
      await cubit.close();
    });

    test('a second save while one is running is ignored', () async {
      when(() => getAccounts(any())).thenAnswer((_) async => const Right<Failure, List<AccountEntity>>([]));
      final gate = Completer<Either<Failure, void>>();
      when(() => saveGoal(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final first = cubit.save(saveParams);
      await cubit.save(saveParams);
      gate.complete(const Right<Failure, void>(null));
      await first;

      verify(() => saveGoal(any())).called(1);
      await cubit.close();
    });

    test('an archived goal closes the form', () async {
      when(() => getAccounts(any())).thenAnswer((_) async => const Right<Failure, List<AccountEntity>>([]));
      when(() => archiveGoal('g1')).thenAnswer((_) async => const Right<Failure, void>(null));
      final cubit = build();
      await cubit.load('w1');

      await cubit.archive('g1');

      expect(cubit.state.status, GoalFormStatus.archived);
      verify(() => archiveGoal('g1')).called(1);
      await cubit.close();
    });

    test('a refused archive keeps the form open and says why', () async {
      when(() => getAccounts(any())).thenAnswer((_) async => const Right<Failure, List<AccountEntity>>([]));
      when(() => archiveGoal(any()))
          .thenAnswer((_) async => const Left<Failure, void>(PermissionFailure('forbidden')));
      final cubit = build();
      await cubit.load('w1');

      await cubit.archive('g1');

      expect(cubit.state.status, GoalFormStatus.ready);
      expect(cubit.state.saveFailure, const PermissionFailure('forbidden'));
      await cubit.close();
    });
  });
}
