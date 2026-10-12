import 'package:finly/core/money/money.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

/// A tip of Amora: what she says and the face she says it with.
class AmoraTip {
  final String text;
  final AmoraMood mood;

  const AmoraTip(this.text, this.mood);
}

/// When nothing needs attention, she shows how to use the app.
const amoraIdleTip = AmoraTip(
  'Dica: toque no + e escreva como você falaria, por exemplo "gastei 50 no mercado ontem".',
  AmoraMood.happy,
);

/// The most useful thing to say today, from what Início already knows. It is
/// worked out in the app: no data goes anywhere.
///
/// In order: a budget over its limit, something to pay in the next 3 days,
/// a budget close to its limit (with how much is left per day), and, when
/// nothing needs attention, a tip about the app.
AmoraTip amoraTipFor({
  required List<BudgetProgress> budgets,
  required List<TransactionEntity> upcoming,
  required DateTime today,
}) {
  String money(int cents, String currency) => Money(cents, currency).format();

  final over = [for (final b in budgets) if (b.level == BudgetLevel.over) b]
    ..sort((a, b) => a.remainingCents.compareTo(b.remainingCents));
  if (over.isNotEmpty) {
    final b = over.first;
    return AmoraTip(
      '${b.category.name} passou ${money(-b.remainingCents, b.currency)} do limite. Quer rever o orçamento?',
      AmoraMood.worried,
    );
  }

  final day = DateTime(today.year, today.month, today.day);
  for (final t in [...upcoming]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt))) {
    if (t.type.isCredit) continue;
    final when = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
    final days = when.difference(day).inDays;
    if (days < 0 || days > 3) continue;
    final label = switch (days) { 0 => 'Hoje', 1 => 'Amanhã', _ => 'Em $days dias' };
    return AmoraTip('$label: ${t.description}, ${money(t.amountCents, t.currency)}.', AmoraMood.happy);
  }

  final warning = [for (final b in budgets) if (b.level == BudgetLevel.warning && b.remainingCents > 0) b]
    ..sort((a, b) => a.remainingCents.compareTo(b.remainingCents));
  if (warning.isNotEmpty) {
    final b = warning.first;
    final last = DateTime(today.year, today.month + 1, 0).day;
    final daysLeft = last - today.day + 1;
    final perDay = b.remainingCents ~/ daysLeft;
    return AmoraTip(
      'Faltam ${money(b.remainingCents, b.currency)} em ${b.category.name}: '
      'uns ${money(perDay, b.currency)} por dia até o fim do mês.',
      AmoraMood.happy,
    );
  }

  return amoraIdleTip;
}
