import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/widgets/new_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_ai_repository.dart';

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

  late MockCreateTransaction create;
  late TransactionFormCubit cubit;
  late FakeAiRepository ai;

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
    ai = FakeAiRepository();
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

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: Scaffold(
                    body: NewTransactionForm(
                      workspaceId: 'w1',
                      accounts: const [itau, nubank],
                      categories: const [market],
                      clock: () => now,
                      ai: ai,
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Finder sentenceField() => find.byType(TextField).first;

  testWidgets('a sentence fills in the sheet, and saving sends what the AI read', (tester) async {
    ai.answer = Right(AiDraft(
      type: TransactionType.expense,
      amountCents: 5000,
      description: 'Mercado',
      categoryId: 'c1',
      accountId: 'a2',
      date: DateTime(2026, 10, 10),
      pending: false,
    ));
    await open(tester);

    await tester.enterText(sentenceField(), 'gastei 50 no mercado ontem no nubank');
    await tester.tap(find.byTooltip('Preencher com a IA'));
    await tester.pumpAndSettle();

    expect(ai.sentences, ['gastei 50 no mercado ontem no nubank']);
    expect(find.text('50,00'), findsOneWidget);
    expect(find.text('Preenchido pela IA. Confira e toque em Salvar.'), findsOneWidget);

    await tester.tap(find.text('Salvar despesa'));
    await tester.pumpAndSettle();

    final sent = verify(() => create(captureAny())).captured.single as CreateTransactionParams;
    expect(sent.amountCents, 5000);
    expect(sent.description, 'Mercado');
    expect(sent.categoryId, 'c1');
    expect(sent.accountId, 'a2');
    expect(sent.occurredAt.day, 10);
  });

  testWidgets('nothing is saved by the AI itself', (tester) async {
    ai.answer = Right(AiDraft(
      type: TransactionType.expense,
      amountCents: 5000,
      description: 'Mercado',
      categoryId: 'c1',
      accountId: 'a1',
      date: now,
      pending: false,
    ));
    await open(tester);

    await tester.enterText(sentenceField(), 'gastei 50 no mercado');
    await tester.tap(find.byTooltip('Preencher com a IA'));
    await tester.pumpAndSettle();

    verifyNever(() => create(any()));
  });

  testWidgets('when the AI cannot help, it says why and the sheet stays as it was', (tester) async {
    ai.answer = const Left(RuleFailure('ai_limit'));
    await open(tester);

    await tester.enterText(sentenceField(), 'gastei 50');
    await tester.tap(find.byTooltip('Preencher com a IA'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Amanhã ela volta'), findsOneWidget);
    expect(find.text('50,00'), findsNothing);
  });

  testWidgets('an income from the AI never stays on a card', (tester) async {
    ai.answer = Right(AiDraft(
      type: TransactionType.income,
      amountCents: 300000,
      description: 'Salário',
      categoryId: null,
      accountId: 'a2',
      date: now,
      pending: false,
    ));
    await open(tester);

    await tester.enterText(sentenceField(), 'recebi 3000 de salário');
    await tester.tap(find.byTooltip('Preencher com a IA'));
    await tester.pumpAndSettle();

    expect(find.text('Nubank'), findsNothing);
    expect(find.text('Itaú'), findsOneWidget);
  });
}
