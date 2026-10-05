/// Income categories go with income, expense categories with expenses.
enum CategoryKind {
  income,
  expense;

  /// The label stored in PostgreSQL is the enum name.
  String get dbValue => name;

  static CategoryKind fromDb(String value) {
    for (final kind in CategoryKind.values) {
      if (kind.name == value) return kind;
    }
    throw ArgumentError.value(value, 'value', 'Unknown category kind');
  }
}