/// Which part of the history is shown.
enum AuditFilter {
  all([]),
  transactions(['transactions', 'transfers']),
  accounts(['accounts', 'credit_card_details', 'credit_card_invoices']),
  categories(['categories']),
  budgets(['budgets']),
  recurring(['recurring_transactions']);

  /// The tables of the log this filter shows (empty: all of them).
  final List<String> tables;

  const AuditFilter(this.tables);
}
