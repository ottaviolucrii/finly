import 'package:finly/core/error/failure.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/presentation/goal_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  String money(int cents) => Money(cents, 'BRL').format();

  GoalProgress progress({int balance = 125000, int target = 500000, DateTime? date}) {
    return GoalProgress(
      goal: Goal(
        id: 'g1',
        workspaceId: 'w1',
        accountId: 'a1',
        currency: 'BRL',
        name: 'Reserva',
        targetCents: target,
        targetDate: date,
      ),
      accountName: 'Poupança',
      balanceCents: balance,
    );
  }

  test('goalAmountsLine says what is saved of the target', () {
    expect(goalAmountsLine(progress()), '${money(125000)} de ${money(500000)}');
  });

  test('goalAmountsLine shows nothing saved for an overdrawn account', () {
    expect(goalAmountsLine(progress(balance: -500)), '${money(0)} de ${money(500000)}');
  });

  group('goalStatusLine', () {
    test('a goal reached', () {
      expect(goalStatusLine(progress(balance: 500000), today), 'Meta alcançada');
    });

    test('a goal with no date says what is missing', () {
      expect(goalStatusLine(progress(), today), 'Faltam ${money(375000)}');
    });

    test('a goal with a date says what to put aside each month', () {
      final line = goalStatusLine(progress(date: DateTime(2027, 1, 5)), today);

      expect(line, 'Faltam ${money(375000)} · guarde ${money(125000)} por mês até 05/01/2027');
    });

    test('a date that is today says so', () {
      final line = goalStatusLine(progress(date: DateTime(2026, 10, 7)), today);

      expect(line, 'Faltam ${money(375000)} · o prazo é hoje');
    });

    test('a date that has passed says it is overdue', () {
      final line = goalStatusLine(progress(date: DateTime(2026, 6, 30)), today);

      expect(line, 'Prazo vencido em 30/06/2026 · faltam ${money(375000)}');
    });

    test('a goal reached after its date is reached, not overdue', () {
      final line = goalStatusLine(progress(balance: 500000, date: DateTime(2026, 6, 30)), today);

      expect(line, 'Meta alcançada');
    });
  });

  group('goalsSummaryLine', () {
    test('counts the goals and the ones reached', () {
      final items = [progress(), progress(balance: 500000), progress(balance: 600000)];

      expect(goalsSummaryLine(items), '3 metas · 2 alcançadas');
    });

    test('says one in the singular', () {
      expect(goalsSummaryLine([progress(balance: 500000)]), '1 meta · 1 alcançada');
    });

    test('none reached', () {
      expect(goalsSummaryLine([progress()]), '1 meta · 0 alcançadas');
    });
  });

  group('goalFailureMessage', () {
    String text(Failure failure) => goalFailureMessage(failure);

    test('a credit card cannot have a goal', () {
      expect(
        text(const RuleFailure('a goal cannot follow a credit card')),
        'Uma meta não pode seguir um cartão de crédito.',
      );
    });

    test('the currency of a goal cannot change', () {
      expect(
        text(const RuleFailure('workspace and currency of a goal are immutable')),
        contains('outra moeda'),
      );
    });

    test('the messages of the form', () {
      expect(text(const ValidationFailure('invalid_name')), contains('nome'));
      expect(text(const ValidationFailure('invalid_target')), contains('maior que zero'));
      expect(text(const ValidationFailure('invalid_account')), 'Escolha uma conta.');
    });

    test('a name already used', () {
      expect(text(const ConflictFailure('already_exists')), 'Já existe uma meta com esse nome.');
    });

    test('no access, no session and no connection', () {
      expect(text(const PermissionFailure('forbidden')), contains('acesso'));
      expect(text(const AuthFailure('not_authenticated')), contains('sessão'));
      expect(text(const NetworkFailure('network_error')), contains('conexão'));
    });

    test('anything else gets a message and never the raw text', () {
      final message = text(const ServerFailure('unknown_error'));

      expect(message, isNotEmpty);
      expect(message, isNot(contains('unknown_error')));
    });
  });
}
