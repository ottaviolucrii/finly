import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/usecases/generate_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/get_recurring_use_case.dart';
import 'package:finly/features/recurring/domain/usecases/set_recurring_active_use_case.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetRecurring extends Mock implements GetRecurringUseCase {}

class MockGenerate extends Mock implements GenerateRecurringUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockGetCategories extends Mock implements GetCategoriesUseCase {}

class MockSetActive extends Mock implements SetRecurringActiveUseCase {}

void main() {
  late MockGetRecurring getRecurring;
  late MockGenerate generate;
  late MockGetAccounts getAccounts;
  late MockGetCategories getCategories;
  late MockSetActive setActive;

  final item = RecurringEntity(
    id: 'r1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    amountCents: 120000,
    currency: 'BRL',
    description: 'Aluguel',
    frequency: RecurrenceFrequency.monthly,
    intervalCount: 1,
    startDate: DateTime(2026, 3, 5),
    endDate: null,
    isActive: true,
  );

  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Conta corrente',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 100000,
  );
  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Moradia',
    kind: CategoryKind.expense,
    icon: 'home',
    colorHex: '#6B5BD2',
    isDefault: true,
  );

  setUpAll(() => registerFallbackValue(
        const SetRecurringActiveParams(id: 'x', active: true),
      ));

  setUp(() {
    getRecurring = MockGetRecurring();
    generate = MockGenerate();
    getAccounts = MockGetAccounts();
    getCategories = MockGetCategories();
    setActive = MockSetActive();

    when(() => generate(const NoParams()))
        .thenAnswer((_) async => const Right<Failure, int>(2));
    when(() => getRecurring('w1')).thenAnswer(
      (_) async => Right<Failure, List<RecurringEntity>>([item]),
    );
    when(() => getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([account]),
    );
    when(() => getCategories('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([category]),
    );
  });

  RecurringCubit buildCubit() => RecurringCubit(
        getRecurring: getRecurring,
        generateRecurring: generate,
        getAccounts: getAccounts,
        getCategories: getCategories,
        setActive: setActive,
      );

  RecurringState loaded({Failure? actionFailure}) => RecurringState(
        status: RecurringStatus.loaded,
        items: [item],
        accounts: const [account],
        categories: const [category],
        actionFailure: actionFailure,
      );

  blocTest<RecurringCubit, RecurringState>(
    'load creates the due occurrences, then emits everything the screen needs',
    build: buildCubit,
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const RecurringState(status: RecurringStatus.loading),
      loaded(),
    ],
    verify: (_) {
      verify(() => generate(const NoParams())).called(1);
      verify(() => getRecurring('w1')).called(1);
    },
  );

  blocTest<RecurringCubit, RecurringState>(
    'a failure while creating occurrences does not stop the list from loading',
    build: () {
      when(() => generate(const NoParams())).thenAnswer(
        (_) async => const Left<Failure, int>(NetworkFailure('network_error')),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const RecurringState(status: RecurringStatus.loading),
      loaded(),
    ],
  );

  blocTest<RecurringCubit, RecurringState>(
    'load fails as a whole when any list fails',
    build: () {
      when(() => getCategories('w1')).thenAnswer(
        (_) async => const Left<Failure, List<CategoryEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const RecurringState(status: RecurringStatus.loading),
      const RecurringState(
        status: RecurringStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<RecurringCubit, RecurringState>(
    'pausing an item reloads the list',
    build: () {
      when(() => setActive(any()))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.toggleActive(item);
    },
    verify: (_) {
      verify(
        () => setActive(const SetRecurringActiveParams(id: 'r1', active: false)),
      ).called(1);
      verify(() => getRecurring('w1')).called(2);
    },
  );

  blocTest<RecurringCubit, RecurringState>(
    'a refused pause keeps the list and reports the reason',
    build: () {
      when(() => setActive(any())).thenAnswer(
        (_) async =>
            const Left<Failure, void>(PermissionFailure('forbidden')),
      );
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.toggleActive(item);
    },
    skip: 2,
    expect: () => [
      loaded(actionFailure: const PermissionFailure('forbidden')),
    ],
  );

  blocTest<RecurringCubit, RecurringState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <RecurringState>[],
    verify: (_) => verifyNever(() => getRecurring(any())),
  );
}