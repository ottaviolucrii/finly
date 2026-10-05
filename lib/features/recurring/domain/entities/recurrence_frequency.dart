/// How often a recurring item repeats. [dbValue] is the label stored in
/// PostgreSQL.
enum RecurrenceFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  String get dbValue => name;

  static RecurrenceFrequency fromDb(String value) {
    for (final frequency in RecurrenceFrequency.values) {
      if (frequency.name == value) return frequency;
    }
    throw ArgumentError.value(value, 'value', 'Unknown recurrence frequency');
  }
}