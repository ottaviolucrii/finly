/// Splits [totalCents] into [parts] installments. The first part absorbs the
/// cents left over by the division, exactly like the database function
/// `create_installments` (SRS BR-14), so the preview matches what is saved.
List<int> splitInstallments(int totalCents, int parts) {
  if (parts < 1) {
    throw ArgumentError.value(parts, 'parts', 'must be at least 1');
  }
  final base = totalCents ~/ parts;
  final remainder = totalCents - base * parts;
  return [base + remainder, for (var i = 1; i < parts; i++) base];
}