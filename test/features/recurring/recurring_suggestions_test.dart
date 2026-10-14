import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/recurring/data/recurring_suggestion_source.dart';
import 'package:finly/features/recurring/domain/entities/recurring_suggestion.dart';
import 'package:finly/features/recurring/presentation/widgets/recurring_suggestions_section.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements RecurringSuggestionSource {
  List<RecurringSuggestion> items;
  final closed = <String>{};

  FakeSource(this.items);

  @override
  Future<List<RecurringSuggestion>> suggestions(String workspaceId) async => items;

  @override
  Future<Set<String>> dismissed(String workspaceId) async => closed;

  @override
  Future<void> dismiss(String workspaceId, RecurringSuggestion suggestion) async => closed.add(suggestion.key);
}

void main() {
  final netflix = RecurringSuggestion(
    description: 'Netflix',
    type: TransactionType.expense,
    amountCents: 3990,
    accountId: 'a1',
    dayOfMonth: 12,
    monthsSeen: 4,
    lastSeen: DateTime(2026, 10, 12),
  );
  final rent = RecurringSuggestion(
    description: 'Aluguel',
    type: TransactionType.expense,
    amountCents: 180000,
    accountId: 'a1',
    dayOfMonth: 5,
    monthsSeen: 5,
    lastSeen: DateTime(2026, 10, 5),
  );

  group('the next date', () {
    test('later this month when the day has not come yet', () {
      expect(nextDayOfMonth(20, DateTime(2026, 10, 14)), DateTime(2026, 10, 20));
    });

    test('today, when it is the day', () {
      expect(nextDayOfMonth(14, DateTime(2026, 10, 14, 18, 30)), DateTime(2026, 10, 14));
    });

    test('next month when the day already passed', () {
      expect(nextDayOfMonth(5, DateTime(2026, 10, 14)), DateTime(2026, 11, 5));
    });

    test('into the next year in December', () {
      expect(nextDayOfMonth(5, DateTime(2026, 12, 14)), DateTime(2027, 1, 5));
    });

    test('the 31st falls on the last day of a shorter month', () {
      expect(nextDayOfMonth(31, DateTime(2026, 11, 14)), DateTime(2026, 11, 30));
      expect(nextDayOfMonth(31, DateTime(2027, 1, 31)), DateTime(2027, 1, 31));
      expect(nextDayOfMonth(31, DateTime(2027, 2, 1)), DateTime(2027, 2, 28));
    });
  });

  group('where the recurring item starts', () {
    RecurringSuggestion seenOn(DateTime? day, {int dayOfMonth = 12}) => RecurringSuggestion(
          description: 'Netflix',
          type: TransactionType.expense,
          amountCents: 3990,
          accountId: 'a1',
          dayOfMonth: dayOfMonth,
          monthsSeen: 4,
          lastSeen: day,
        );

    test('seen this month already (paid early): it starts next month, not on a twin', () {
      expect(suggestedStart(seenOn(DateTime(2026, 10, 3)), DateTime(2026, 10, 5)), DateTime(2026, 11, 12));
    });

    test('seen this month on the usual day: next month', () {
      expect(suggestedStart(seenOn(DateTime(2026, 10, 12)), DateTime(2026, 10, 14)), DateTime(2026, 11, 12));
    });

    test('last seen last month and the day has not come yet: this month', () {
      expect(suggestedStart(seenOn(DateTime(2026, 9, 12)), DateTime(2026, 10, 5)), DateTime(2026, 10, 12));
    });

    test('never in the past: last seen long ago, the day already passed', () {
      expect(suggestedStart(seenOn(DateTime(2026, 8, 12)), DateTime(2026, 10, 14)), DateTime(2026, 11, 12));
    });

    test('an upcoming entry already exists: it starts after it', () {
      expect(suggestedStart(seenOn(DateTime(2026, 12, 12)), DateTime(2026, 10, 14)), DateTime(2027, 1, 12));
    });

    test('without a last date it is the next time that day comes', () {
      expect(suggestedStart(seenOn(null), DateTime(2026, 10, 14)), DateTime(2026, 11, 12));
    });

    test('the 31st on a short month', () {
      expect(suggestedStart(seenOn(DateTime(2027, 1, 31), dayOfMonth: 31), DateTime(2027, 2, 2)), DateTime(2027, 2, 28));
    });
  });

  test('a suggestion is read from the database row', () {
    final s = RecurringSuggestion.fromMap({
      'description': 'Netflix',
      'type': 'expense',
      'amount_cents': 3990,
      'account_id': 'a1',
      'category_id': null,
      'day_of_month': 12,
      'months_seen': 4,
      'last_seen': '2026-10-12',
    });

    expect(s, netflix);
    expect(s.key, 'netflix');
  });

  group('A Amora notou', () {
    late FakeSource source;
    late List<RecurringSuggestion> asked;
    var createResult = true;

    setUp(() {
      source = FakeSource([netflix, rent]);
      asked = [];
      createResult = true;
    });

    Future<void> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                RecurringSuggestionsSection(
                  workspaceId: 'w1',
                  source: source,
                  onCreate: (suggestion) async {
                    asked.add(suggestion);
                    return createResult;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows what repeats, with the amount, the day and how many months', (tester) async {
      await show(tester);

      expect(find.text('A Amora notou'), findsOneWidget);
      expect(find.text('Netflix'), findsOneWidget);
      expect(find.textContaining('Saída de R\$ 39,90 · perto do dia 12 · vista em 4 meses'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('nothing to suggest shows nothing', (tester) async {
      source = FakeSource([]);
      await show(tester);

      expect(find.text('A Amora notou'), findsNothing);
    });

    testWidgets('the ones closed before do not come back', (tester) async {
      source.closed.add('netflix');
      await show(tester);

      expect(find.text('Netflix'), findsNothing);
      expect(find.text('Aluguel'), findsOneWidget);
    });

    testWidgets('"Criar recorrência" opens the form with that suggestion, and it leaves once created', (tester) async {
      await show(tester);

      await tester.tap(find.text('Criar recorrência').first);
      await tester.pumpAndSettle();

      expect(asked, [netflix]);
      expect(find.text('Netflix'), findsNothing);
    });

    testWidgets('when the form is closed without creating, the suggestion stays', (tester) async {
      createResult = false;
      await show(tester);

      await tester.tap(find.text('Criar recorrência').first);
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsOneWidget);
    });

    testWidgets('"Agora não" removes it and remembers', (tester) async {
      await show(tester);

      await tester.tap(find.text('Agora não').first);
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsNothing);
      expect(source.closed, {'netflix'});
    });
  });
}
