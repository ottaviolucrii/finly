import 'package:bloc_test/bloc_test.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_category.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_categories_state.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_state.dart';
import 'package:finly/features/tax_reserve/presentation/pages/tax_reserve_page.dart';
import 'package:finly/features/tax_reserve/presentation/widgets/tax_categories_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoriesCubit extends MockCubit<TaxCategoriesState> implements TaxCategoriesCubit {}

class MockReserveCubit extends MockCubit<TaxReserveState> implements TaxReserveCubit {}

void main() {
  late MockCategoriesCubit categoriesCubit;
  late MockReserveCubit reserveCubit;

  const impostos = TaxCategory(id: 'c1', name: 'Impostos', colorHex: '#1060E3', isTax: true);
  const aluguel = TaxCategory(id: 'c2', name: 'Aluguel', colorHex: '#F29D38', isTax: false);

  setUp(() {
    categoriesCubit = MockCategoriesCubit();
    reserveCubit = MockReserveCubit();
    when(() => categoriesCubit.setTax(any(), isTax: any(named: 'isTax'))).thenAnswer((_) async {});
    when(() => categoriesCubit.reload()).thenAnswer((_) async {});
    when(() => reserveCubit.reload()).thenAnswer((_) async {});
  });

  TaxCategoriesState loaded(List<TaxCategory> list, {String? savingId}) {
    return TaxCategoriesState(
      status: TaxCategoriesStatus.loaded,
      categories: list,
      savingId: savingId,
    );
  }

  Future<void> show(
    WidgetTester tester,
    TaxCategoriesState state, {
    Stream<TaxCategoriesState>? later,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    whenListen(categoriesCubit, later ?? const Stream<TaxCategoriesState>.empty(), initialState: state);
    whenListen(
      reserveCubit,
      const Stream<TaxReserveState>.empty(),
      initialState: TaxReserveState(month: DateTime(2026, 10), currentMonth: DateTime(2026, 10)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<TaxCategoriesCubit>.value(value: categoriesCubit),
              BlocProvider<TaxReserveCubit>.value(value: reserveCubit),
            ],
            child: const SingleChildScrollView(child: TaxCategoriesCard()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.text('Categorias de imposto'));
    // Not pumpAndSettle: a spinner inside never stops animating. The first pump
    // starts the opening animation, the second one lets it run to the end.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('taxCategoryColor', () {
    test('reads a hex colour of the database', () {
      expect(taxCategoryColor('#1060E3'), const Color(0xFF1060E3));
      expect(taxCategoryColor('#f29d38'), const Color(0xFFF29D38));
    });

    test('anything else is grey', () {
      expect(taxCategoryColor(''), Colors.grey);
      expect(taxCategoryColor('azul'), Colors.grey);
      expect(taxCategoryColor('#12345'), Colors.grey);
    });
  });

  testWidgets('says which categories count, before it is opened', (tester) async {
    await show(tester, loaded([impostos, aluguel]));

    expect(find.text('Categorias de imposto'), findsOneWidget);
    expect(find.text('Impostos'), findsOneWidget);
    expect(find.text('Aluguel'), findsNothing);
  });

  testWidgets('says when none is marked', (tester) async {
    await show(tester, loaded([aluguel]));

    expect(find.text('Nenhuma marcada'), findsOneWidget);
  });

  testWidgets('once opened, shows a switch for each category', (tester) async {
    await show(tester, loaded([impostos, aluguel]));

    await expand(tester);

    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches, hasLength(2));
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
    expect(find.textContaining('entram em'), findsOneWidget);
  });

  testWidgets('turning a switch on asks the cubit to mark the category', (tester) async {
    await show(tester, loaded([impostos, aluguel]));
    await expand(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Aluguel'));
    await tester.pump();

    verify(() => categoriesCubit.setTax('c2', isTax: true)).called(1);
  });

  testWidgets('turning a switch off asks the cubit to take the mark off', (tester) async {
    await show(tester, loaded([impostos, aluguel]));
    await expand(tester);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Impostos'));
    await tester.pump();

    verify(() => categoriesCubit.setTax('c1', isTax: false)).called(1);
  });

  testWidgets('the switches are off while a change is being saved', (tester) async {
    await show(tester, loaded([impostos, aluguel], savingId: 'c2'));
    await expand(tester);

    for (final tile in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))) {
      expect(tile.onChanged, isNull);
    }
  });

  testWidgets('shows a spinner while the categories load', (tester) async {
    await show(tester, const TaxCategoriesState());
    await expand(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('offers to try again when the categories could not be read', (tester) async {
    await show(
      tester,
      const TaxCategoriesState(
        status: TaxCategoriesStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    );
    await expand(tester);

    expect(find.textContaining('conexão'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    verify(() => categoriesCubit.reload()).called(1);
  });

  testWidgets('says when the workspace has no expense categories', (tester) async {
    await show(tester, loaded(const []));
    await expand(tester);

    expect(find.textContaining('não tem categorias'), findsOneWidget);
  });

  testWidgets('says why a change was refused, and does not read the numbers again', (tester) async {
    await show(
      tester,
      loaded([impostos, aluguel]),
      later: Stream.value(
        TaxCategoriesState(
          status: TaxCategoriesStatus.loaded,
          categories: const [impostos, aluguel],
          saveFailure: const RuleFailure('violates check constraint'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
    verifyNever(() => reserveCubit.reload());
  });

  testWidgets('reads the numbers of the screen again when a change was saved', (tester) async {
    await show(
      tester,
      loaded([impostos, aluguel]),
      later: Stream.value(
        const TaxCategoriesState(
          status: TaxCategoriesStatus.loaded,
          categories: [impostos, aluguel],
          changes: 1,
        ),
      ),
    );
    await tester.pump();

    verify(() => reserveCubit.reload()).called(1);
  });

  testWidgets('the tax reserve screen shows the extra card under its numbers', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    whenListen(
      reserveCubit,
      const Stream<TaxReserveState>.empty(),
      initialState: TaxReserveState(
        status: TaxReserveStatus.loaded,
        month: DateTime(2026, 10),
        currentMonth: DateTime(2026, 10),
        data: const TaxReserveData(
          percentBps: 650,
          currency: 'BRL',
          incomeCents: 500000,
          taxCents: 12000,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaxReserveCubit>.value(
          value: reserveCubit,
          child: const TaxReserveView(extra: Text('um cartão extra')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('um cartão extra'), findsOneWidget);
    expect(find.text('Reserva de 6,5%'), findsOneWidget);
  });
}
