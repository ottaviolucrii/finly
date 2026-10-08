import 'package:finly/core/error/failure.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/goal_rules.dart';

/// "R$ 3.000,00 de R$ 5.000,00".
String goalAmountsLine(GoalProgress progress) {
  final currency = progress.goal.currency;
  return '${Money(progress.savedCents, currency).format()} de '
      '${Money(progress.goal.targetCents, currency).format()}';
}

/// What is left to do, in a sentence (Portuguese for now; replaced by proper
/// localisation in a later phase).
String goalStatusLine(GoalProgress progress, DateTime today) {
  final currency = progress.goal.currency;
  final remaining = Money(progress.remainingCents, currency).format();
  final date = progress.goal.targetDate;

  switch (progress.statusAt(today)) {
    case GoalStatus.achieved:
      return 'Meta alcançada';
    case GoalStatus.open:
      return 'Faltam $remaining';
    case GoalStatus.overdue:
      return 'Prazo vencido em ${formatDateBr(date!)} · faltam $remaining';
    case GoalStatus.onTrack:
      final monthly = progress.monthlyNeededAt(today);
      if (monthly == null) return 'Faltam $remaining · o prazo é hoje';
      return 'Faltam $remaining · guarde ${Money(monthly, currency).format()} '
          'por mês até ${formatDateBr(date!)}';
  }
}

/// "3 metas · 1 alcançada".
String goalsSummaryLine(List<GoalProgress> items) {
  final achieved = items.where((item) => item.achieved).length;
  final goals = items.length == 1 ? '1 meta' : '${items.length} metas';
  final reached = achieved == 1 ? '1 alcançada' : '$achieved alcançadas';
  return '$goals · $reached';
}

/// The text for a failure on the goals screens (Portuguese for now).
String goalFailureMessage(Failure failure) {
  final message = failure.message;

  if (message.contains('cannot follow a credit card')) {
    return 'Uma meta não pode seguir um cartão de crédito.';
  }
  if (message.contains('immutable')) {
    return 'Não dá para trocar a meta para uma conta de outra moeda.';
  }

  switch (message) {
    case 'invalid_name':
      return 'Informe um nome de até 80 caracteres.';
    case 'invalid_target':
      return 'Informe um valor maior que zero.';
    case 'invalid_account':
      return 'Escolha uma conta.';
    case 'already_exists':
      return 'Já existe uma meta com esse nome.';
    case 'forbidden':
      return 'Você não tem acesso a este workspace.';
    case 'not_authenticated':
      return 'Sua sessão expirou. Entre novamente.';
    case 'network_error':
      return 'Sem conexão. Verifique sua internet.';
    default:
      return 'Algo deu errado. Tente novamente.';
  }
}
