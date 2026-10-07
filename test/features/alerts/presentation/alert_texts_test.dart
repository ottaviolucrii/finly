import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/alerts/presentation/alert_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppAlert alert(
    AlertKind kind, {
    String subject = 'Aluguel',
    int amount = 150000,
    int? limit,
    int? percent,
    DateTime? dueDate,
    int? days,
  }) {
    return AppAlert(
      kind: kind,
      subject: subject,
      currency: 'BRL',
      amountCents: amount,
      limitCents: limit,
      percent: percent,
      dueDate: dueDate,
      daysUntilDue: days,
    );
  }

  group('alertTitle', () {
    test('a budget over the limit', () {
      expect(
        alertTitle(alert(AlertKind.budgetOver, subject: 'Lazer', percent: 120)),
        'Orçamento de Lazer estourado',
      );
    });

    test('a budget near the limit shows the percent', () {
      expect(
        alertTitle(alert(AlertKind.budgetNear, subject: 'Lazer', percent: 87)),
        'Orçamento de Lazer em 87%',
      );
    });

    test('an overdue bill', () {
      expect(alertTitle(alert(AlertKind.billOverdue)), 'Atrasado: Aluguel');
    });

    test('a bill due today', () {
      expect(alertTitle(alert(AlertKind.billDueToday)), 'Vence hoje: Aluguel');
    });

    test('a bill due tomorrow says tomorrow', () {
      expect(alertTitle(alert(AlertKind.billDueSoon, days: 1)), 'Vence amanhã: Aluguel');
    });

    test('a bill due in several days says how many', () {
      expect(alertTitle(alert(AlertKind.billDueSoon, days: 3)), 'Vence em 3 dias: Aluguel');
    });
  });

  group('alertDetail', () {
    test('a budget over the limit shows the percent', () {
      final text = alertDetail(
        alert(AlertKind.budgetOver, amount: 120000, limit: 100000, percent: 120),
      );

      expect(text, contains(' de '));
      expect(text, endsWith('(120%)'));
    });

    test('a budget near the limit shows spent and limit', () {
      final text = alertDetail(
        alert(AlertKind.budgetNear, amount: 90000, limit: 100000, percent: 90),
      );

      expect(text, contains(' de '));
      expect(text, isNot(contains('%')));
    });

    test('an overdue bill says how long ago, with the date', () {
      final text = alertDetail(
        alert(AlertKind.billOverdue, dueDate: DateTime(2026, 10, 3), days: -3),
      );

      expect(text, contains('venceu há 3 dias'));
      expect(text, contains('03/10/2026'));
    });

    test('a bill overdue since yesterday says yesterday', () {
      final text = alertDetail(
        alert(AlertKind.billOverdue, dueDate: DateTime(2026, 10, 5), days: -1),
      );

      expect(text, contains('venceu ontem'));
    });

    test('a bill due soon shows the date', () {
      final text = alertDetail(
        alert(AlertKind.billDueSoon, dueDate: DateTime(2026, 10, 8), days: 2),
      );

      expect(text, contains('08/10/2026'));
    });

    test('a bill due today shows only the amount', () {
      final text = alertDetail(alert(AlertKind.billDueToday, dueDate: DateTime(2026, 10, 6), days: 0));

      expect(text, isNot(contains('·')));
    });
  });
}