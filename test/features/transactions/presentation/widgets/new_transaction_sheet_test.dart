import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:finly/features/transactions/presentation/widgets/new_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateTransaction extends Mock implements CreateTransactionUseCase {}

void main() {
  final now = DateTime(2026, 10, 11, 15, 30);

  const itau = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Itaú',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );
  const nubank = AccountEntity(
    id: 'a2',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.creditCard,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );
  const market = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_cart',
    colorHex: '#F29D38',
    isDefault: true,
  );
  const salary = CategoryEntity(
    id: 'c2',
    workspaceId: 'w1',
    name: 'Salário',
    kind: CategoryKind.income,
    icon: 'payments',
    colorHex: '#1060E3',
    isDefault: true,
  );

  late MockCreateTransaction create;
  late TransactionFormCubit cubit;
  NewTransactionResult? result;

  setUpAll(() {
    registerFallbackValue(CreateTransactionParams(
      workspaceId: 'w1',
      accountId: 'a1',
      type: TransactionType.expense,
      status: TransactionStatus.posted,
      amountCents: 1,
      currency: 'BRL',
      description: 'x',
      occurredAt: DateTime(2026),
    ));
  });

  setUp(() {
    create = MockCreateTransaction();
    cubit = TransactionFormCubit(create);
    result = null;
    when(() => create(any())).thenAnswer((invocation) async {
      final params = invocation.positionalArguments.single as CreateTransactionParams;
      return Right<Failure, TransactionEntity>(TransactionEntity(
        id: 't1',
        workspaceId: params.workspaceId,
        accountId: params.accountId,
        categoryId: params.categoryId,
        type: params.type,
        status: params.status,
        amountCents: params.amountCents,
        currency: params.currency,
        description: params.description,
        occurredAt: params.occurredAt,
      ));
    });
  });

  tearDown(() => cubit.close());

  /// Opens the form in its own route, like the sheet does, so it can close
  /// with a result.
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NewTransactionResult>(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: cubit,
                    child: Scaffold(
                      body: NewTransactionForm(
                        workspaceId: 'w1',
                        accounts: const [itau, nubank],
                        categories: const [market, salary],
                        clock: () => now,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  CreateTransactionParams sent() =>
      verify(() => create(captureAny())).captured.single as CreateTransactionParams;

  Finder amountField() => find.byType(TextFormField).at(0);
  Finder descriptionField() => find.byType(TextFormField).at(1);

  testWidgets('starts as an expense, today, on the first account', (tester) async {
    await open(tester);

    expect(find.text('Novo lançamento'), findsOneWidget);
    for (final label in ['Despesa', 'Receita', 'Transferência', 'Mercado', 'Itaú', 'Nubank', 'Hoje', 'Ontem', 'Outra data']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Pagar com'), findsOneWidget);
    expect(find.text('Salário'), findsNothing);
    expect(find.text('Salvar despesa'), findsOneWidget);
  });

  testWidgets('an income shows income categories and "Receber em"', (tester) async {
    await open(tester);

    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();

    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Mercado'), findsNothing);
    expect(find.text('Receber em'), findsOneWidget);
    expect(find.text('Salvar receita'), findsOneWidget);
  });

  testWidgets('an income does not offer the credit card', (tester) async {
    await open(tester);

    expect(find.text('Nubank'), findsOneWidget);
    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();

    expect(find.text('Itaú'), findsOneWidget);
    expect(find.text('Nubank'), findsNothing);
  });

  testWidgets('an income moves off a card chosen before', (tester) async {
    await open(tester);

    await tester.tap(find.text('Nubank'));
    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    await tester.enterText(amountField(), '300000');
    await tester.tap(find.text('Salário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar receita'));
    await tester.pumpAndSettle();

    expect(sent().accountId, 'a1');
  });

  testWidgets('asks for an amount and a description before saving', (tester) async {
    await open(tester);

    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o valor.'), findsOneWidget);
    expect(find.text('Escreva uma descrição ou escolha uma categoria.'), findsOneWidget);
    verifyNever(() => create(any()));
  });

  testWidgets('saves with the category name when there is no description', (tester) async {
    await open(tester);

    await tester.enterText(amountField(), '25,90');
    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    final params = sent();
    expect(params.amountCents, 2590);
    expect(params.description, 'Mercado');
    expect(params.categoryId, 'c1');
    expect(params.accountId, 'a1');
    expect(params.type, TransactionType.expense);
    expect(params.status, TransactionStatus.posted);
    expect(params.occurredAt, now);
    expect(result, NewTransactionResult.created);
  });

  testWidgets('the amount is typed digit by digit, the comma places itself', (tester) async {
    await open(tester);

    await tester.enterText(amountField(), '5350');
    await tester.pump();

    expect(find.text('53,50'), findsOneWidget);
  });

  testWidgets('a wrong format cannot be typed', (tester) async {
    await open(tester);

    await tester.enterText(amountField(), '58.5333');
    await tester.pump();

    // Only the digits count: 585333 cents.
    expect(find.text('5.853,33'), findsOneWidget);
  });

  testWidgets('saves yesterday, on another account, as pending', (tester) async {
    await open(tester);

    await tester.enterText(amountField(), '100');
    await tester.enterText(descriptionField(), 'Luz');
    await tester.tap(find.text('Nubank'));
    await tester.tap(find.text('Ontem'));
    await tester.tap(find.text('Ainda não aconteceu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    final params = sent();
    expect(params.amountCents, 100);
    expect(params.description, 'Luz');
    expect(params.accountId, 'a2');
    expect(params.occurredAt, DateTime(2026, 10, 10, 12));
    expect(params.status, TransactionStatus.pending);
  });

  testWidgets('"Transferência" closes the sheet to open the transfer', (tester) async {
    await open(tester);

    await tester.tap(find.text('Transferência'));
    await tester.pumpAndSettle();

    expect(result, NewTransactionResult.transfer);
    verifyNever(() => create(any()));
  });

  testWidgets('a failure keeps the sheet open with what was typed', (tester) async {
    when(() => create(any())).thenAnswer((_) async => const Left(NetworkFailure('network_error')));
    await open(tester);

    await tester.enterText(amountField(), '10');
    await tester.enterText(descriptionField(), 'Café');
    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Café'), findsOneWidget);
    // The reason shows inside the sheet, above the button.
    expect(find.text(transactionFailureMessage(const NetworkFailure('network_error'))), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('the reason goes away on the next try', (tester) async {
    var calls = 0;
    when(() => create(any())).thenAnswer((invocation) async {
      calls++;
      if (calls == 1) return const Left(NetworkFailure('network_error'));
      final params = invocation.positionalArguments.single as CreateTransactionParams;
      return Right<Failure, TransactionEntity>(TransactionEntity(
        id: 't1',
        workspaceId: params.workspaceId,
        accountId: params.accountId,
        categoryId: params.categoryId,
        type: params.type,
        status: params.status,
        amountCents: params.amountCents,
        currency: params.currency,
        description: params.description,
        occurredAt: params.occurredAt,
      ));
    });
    await open(tester);

    await tester.enterText(amountField(), '10');
    await tester.enterText(descriptionField(), 'Café');
    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    expect(result, NewTransactionResult.created);
  });

  testWidgets('closing does not save', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    verifyNever(() => create(any()));
  });
}
