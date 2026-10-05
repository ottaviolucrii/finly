import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/presentation/recurring_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frequencyLabel', () {
    test('every one uses the short forms', () {
      expect(frequencyLabel(RecurrenceFrequency.daily, 1), 'todo dia');
      expect(frequencyLabel(RecurrenceFrequency.weekly, 1), 'toda semana');
      expect(frequencyLabel(RecurrenceFrequency.monthly, 1), 'todo mês');
      expect(frequencyLabel(RecurrenceFrequency.yearly, 1), 'todo ano');
    });

    test('an interval uses "a cada" and the plural', () {
      expect(frequencyLabel(RecurrenceFrequency.daily, 3), 'a cada 3 dias');
      expect(frequencyLabel(RecurrenceFrequency.weekly, 2), 'a cada 2 semanas');
      expect(frequencyLabel(RecurrenceFrequency.monthly, 6), 'a cada 6 meses');
      expect(frequencyLabel(RecurrenceFrequency.yearly, 2), 'a cada 2 anos');
    });
  });

  test('chip labels and form units are in Portuguese', () {
    expect(frequencyChipLabel(RecurrenceFrequency.monthly), 'Mensal');
    expect(frequencyChipLabel(RecurrenceFrequency.yearly), 'Anual');
    expect(frequencyUnit(RecurrenceFrequency.weekly), 'semana(s)');
    expect(frequencyUnit(RecurrenceFrequency.monthly), 'mês(es)');
  });
}