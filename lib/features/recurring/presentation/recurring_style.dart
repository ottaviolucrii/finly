import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';

/// "todo mês", "a cada 2 semanas".
String frequencyLabel(RecurrenceFrequency frequency, int intervalCount) {
  if (intervalCount <= 1) {
    return switch (frequency) {
      RecurrenceFrequency.daily => 'todo dia',
      RecurrenceFrequency.weekly => 'toda semana',
      RecurrenceFrequency.monthly => 'todo mês',
      RecurrenceFrequency.yearly => 'todo ano',
    };
  }
  final unit = switch (frequency) {
    RecurrenceFrequency.daily => 'dias',
    RecurrenceFrequency.weekly => 'semanas',
    RecurrenceFrequency.monthly => 'meses',
    RecurrenceFrequency.yearly => 'anos',
  };
  return 'a cada $intervalCount $unit';
}

/// The name of a frequency on a chip.
String frequencyChipLabel(RecurrenceFrequency frequency) => switch (frequency) {
      RecurrenceFrequency.daily => 'Diária',
      RecurrenceFrequency.weekly => 'Semanal',
      RecurrenceFrequency.monthly => 'Mensal',
      RecurrenceFrequency.yearly => 'Anual',
    };

/// The unit that follows "A cada" in the form, always in the plural.
String frequencyUnit(RecurrenceFrequency frequency) => switch (frequency) {
      RecurrenceFrequency.daily => 'dia(s)',
      RecurrenceFrequency.weekly => 'semana(s)',
      RecurrenceFrequency.monthly => 'mês(es)',
      RecurrenceFrequency.yearly => 'ano(s)',
    };