import 'package:dartz/dartz.dart' show Either, Left, Right;
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/summary/data/summary_notifier.dart';
import 'package:finly/features/summary/data/summary_store.dart';
import 'package:finly/features/summary/presentation/month_summary_card.dart';
import 'package:finly/features/summary/presentation/month_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySummaryStore implements SummaryStore {
  final closed = <String>{};

  String _id(String workspaceId, DateTime month) => '$workspaceId ${month.year}-${month.month}';

  @override
  Future<bool> isDismissed(String workspaceId, DateTime month) async => closed.contains(_id(workspaceId, month));

  @override
  Future<void> dismiss(String workspaceId, DateTime month) async => closed.add(_id(workspaceId, month));
}

class FakeNotifier implements SummaryNotifier {
  int rearms = 0;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<bool> setEnabled(bool enabled) async => true;

  @override
  Future<void> rearm() async => rearms++;
}

void main() {
  MonthlyReport report({int income = 500000, int expense = 220000}) => MonthlyReport(
        month: DateTime(2026, 9),
        byCurrency: [
          CurrencyReport(
            currency: 'BRL',
            incomeCents: income,
            expenseCents: expense,
            previousIncomeCents: 0,
            previousExpenseCents: 250000,
            categories: const [
              CategoryChange(name: 'Mercado', colorHex: '#F29D38', spentCents: 90000, previousCents: 80000),
            ],
            topExpenses: const [],
          ),
        ],
      );

  late MemorySummaryStore store;
  late List<DateTime> asked;
  late List<DateTime> opened;

  setUp(() {
    store = MemorySummaryStore();
    asked = [];
    opened = [];
  });

  Future<Either<Failure, MonthlyReport>> Function(DateTime) loader({MonthlyReport? data, bool fail = false}) =>
      (month) async {
        asked.add(month);
        return fail ? const Left(ServerFailure('x')) : Right(data ?? report());
      };

  Future<void> showCard(WidgetTester tester, DateTime today, {SummaryLoader? load, SummaryNotifier? notifier}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              MonthSummaryCard(
                workspaceId: 'w1',
                today: today,
                load: load ?? loader(),
                store: store,
                notifier: notifier,
                onOpen: opened.add,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the card on Início', () {
    testWidgets('on the 1st it tells how the month that ended went', (tester) async {
      await showCard(tester, DateTime(2026, 10, 1));

      expect(asked, [DateTime(2026, 9)]);
      expect(find.text('Resumo de setembro'), findsOneWidget);
      expect(find.textContaining('você gastou 12% a menos'), findsOneWidget);
    });

    testWidgets('in January it is about December of the year before', (tester) async {
      await showCard(tester, DateTime(2027, 1, 3));

      expect(asked, [DateTime(2026, 12)]);
    });

    testWidgets('after the 7th it is gone, and nothing is read', (tester) async {
      await showCard(tester, DateTime(2026, 10, 8));

      expect(asked, isEmpty);
      expect(find.textContaining('Resumo de'), findsNothing);
    });

    testWidgets('a month without movement shows nothing', (tester) async {
      await showCard(tester, DateTime(2026, 10, 2), load: loader(data: report(income: 0, expense: 0)));

      expect(find.textContaining('Resumo de'), findsNothing);
    });

    testWidgets('when it cannot be read, it shows nothing instead of an error', (tester) async {
      await showCard(tester, DateTime(2026, 10, 2), load: loader(fail: true));

      expect(find.textContaining('Resumo de'), findsNothing);
    });

    testWidgets('a tap opens that month', (tester) async {
      await showCard(tester, DateTime(2026, 10, 2));

      await tester.tap(find.text('Resumo de setembro'));

      expect(opened, [DateTime(2026, 9)]);
    });

    testWidgets('closing it keeps it closed for that month', (tester) async {
      await showCard(tester, DateTime(2026, 10, 2));
      await tester.tap(find.byTooltip('Esconder o resumo'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo de setembro'), findsNothing);
      expect(store.closed, {'w1 2026-9'});

      // a new visit to Início: a fresh card, which must not even ask for the data
      await tester.pumpWidget(const SizedBox());
      await showCard(tester, DateTime(2026, 10, 3));

      expect(find.text('Resumo de setembro'), findsNothing);
      expect(asked, [DateTime(2026, 9)]);
    });

    testWidgets('it asks the notification to be scheduled again', (tester) async {
      final notifier = FakeNotifier();
      await showCard(tester, DateTime(2026, 10, 20), notifier: notifier);

      expect(notifier.rearms, 1);
    });
  });

  group('the page', () {
    Future<void> showPage(WidgetTester tester, {required DateTime month, SummaryLoader? load}) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MonthSummaryPage(
            initialMonth: month,
            today: DateTime(2026, 10, 14),
            load: load ?? loader(),
            onOpenReport: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the headline and the lines of the month', (tester) async {
      await showPage(tester, month: DateTime(2026, 9));

      expect(find.text('Setembro de 2026'), findsOneWidget);
      expect(find.textContaining('Entraram R\$ 5.000,00'), findsOneWidget);
      expect(find.textContaining('Onde mais gastou: Mercado'), findsOneWidget);
      expect(find.text('Ver o relatório completo'), findsOneWidget);
    });

    testWidgets('the month in progress says so, and has no next month', (tester) async {
      await showPage(tester, month: DateTime(2026, 10));

      expect(find.textContaining('ainda não acabou'), findsOneWidget);
      final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(next.onPressed, isNull);
    });

    testWidgets('the arrows go to the month before', (tester) async {
      await showPage(tester, month: DateTime(2026, 9));

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();

      expect(asked.last, DateTime(2026, 8));
      expect(find.text('Agosto de 2026'), findsOneWidget);
    });

    testWidgets('an empty month says there is nothing yet', (tester) async {
      await showPage(tester, month: DateTime(2026, 9), load: loader(data: report(income: 0, expense: 0)));

      expect(find.textContaining('Sem movimento'), findsOneWidget);
    });

    testWidgets('a failure offers to try again', (tester) async {
      await showPage(tester, month: DateTime(2026, 9), load: loader(fail: true));

      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}
