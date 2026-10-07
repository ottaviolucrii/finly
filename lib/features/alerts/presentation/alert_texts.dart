import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';

/// The headline of an alert (Portuguese for now; replaced by proper
/// localisation in a later phase).
String alertTitle(AppAlert alert) {
  switch (alert.kind) {
    case AlertKind.budgetOver:
      return 'Orçamento de ${alert.subject} estourado';
    case AlertKind.budgetNear:
      return 'Orçamento de ${alert.subject} em ${alert.percent}%';
    case AlertKind.billOverdue:
      return 'Atrasado: ${alert.subject}';
    case AlertKind.billDueToday:
      return 'Vence hoje: ${alert.subject}';
    case AlertKind.billDueSoon:
      final days = alert.daysUntilDue ?? 0;
      return days == 1
          ? 'Vence amanhã: ${alert.subject}'
          : 'Vence em $days dias: ${alert.subject}';
  }
}

/// The second line of an alert: the amounts and, for a bill, the date.
String alertDetail(AppAlert alert) {
  final amount = Money(alert.amountCents, alert.currency).format();

  switch (alert.kind) {
    case AlertKind.budgetOver:
      final limit = Money(alert.limitCents ?? 0, alert.currency).format();
      return '$amount de $limit (${alert.percent}%)';
    case AlertKind.budgetNear:
      final limit = Money(alert.limitCents ?? 0, alert.currency).format();
      return '$amount de $limit';
    case AlertKind.billOverdue:
      final days = -(alert.daysUntilDue ?? 0);
      final when = days == 1 ? 'ontem' : 'há $days dias';
      final date = alert.dueDate == null ? '' : ' (${formatDateBr(alert.dueDate!)})';
      return '$amount · venceu $when$date';
    case AlertKind.billDueToday:
      return amount;
    case AlertKind.billDueSoon:
      final date = alert.dueDate == null ? '' : ' · ${formatDateBr(alert.dueDate!)}';
      return '$amount$date';
  }
}