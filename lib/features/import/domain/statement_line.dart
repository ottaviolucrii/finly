import 'package:equatable/equatable.dart';

/// One line of a bank statement, as read from the file.
class StatementLine extends Equatable {
  final DateTime date;

  /// Negative: money going out. Positive: money coming in.
  final int amountCents;
  final String description;

  /// The bank's own id for the line (the FITID of an OFX), when there is one.
  final String? externalId;

  const StatementLine({
    required this.date,
    required this.amountCents,
    required this.description,
    this.externalId,
  });

  StatementLine withSignInverted() =>
      StatementLine(date: date, amountCents: -amountCents, description: description, externalId: externalId);

  @override
  List<Object?> get props => [date, amountCents, description, externalId];
}

/// What was read from a file: the lines, whether it looks like a credit card
/// statement, and how many lines could not be read.
class StatementFile extends Equatable {
  final List<StatementLine> lines;
  final bool looksLikeCard;
  final int skipped;

  const StatementFile({required this.lines, this.looksLikeCard = false, this.skipped = 0});

  @override
  List<Object?> get props => [lines, looksLikeCard, skipped];
}
