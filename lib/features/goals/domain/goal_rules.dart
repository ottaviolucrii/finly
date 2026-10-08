/// Where a goal stands.
enum GoalStatus {
  /// The account holds the target or more.
  achieved,

  /// There is a date and it has passed, with the target not reached.
  overdue,

  /// There is a date that has not come yet.
  onTrack,

  /// No date: the goal is open-ended.
  open,
}

/// What counts as saved: the balance of the account, never below zero (an
/// overdrawn account is not "negative savings").
int savedFor(int balanceCents) => balanceCents > 0 ? balanceCents : 0;

/// The share of the target that is saved, in whole percent rounded down, from 0
/// to 100: 99,9% shows 99%, never 100% before the target is reached.
int progressPercent(int savedCents, int targetCents) {
  if (targetCents <= 0 || savedCents <= 0) return 0;
  if (savedCents >= targetCents) return 100;
  return savedCents * 100 ~/ targetCents;
}

/// What is missing to reach the target (0 once it is reached).
int remainingFor(int savedCents, int targetCents) {
  return targetCents > savedCents ? targetCents - savedCents : 0;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Whole days from [today] to [targetDate] (negative when it has passed).
int daysLeft(DateTime today, DateTime targetDate) {
  final from = _dateOnly(today);
  final to = _dateOnly(targetDate);
  return DateTime.utc(to.year, to.month, to.day)
      .difference(DateTime.utc(from.year, from.month, from.day))
      .inDays;
}

/// How many months to count for [days] days left: every started 30 days is a
/// month, and at least one while there is time. Zero when there is none.
int monthsLeft(int days) => days <= 0 ? 0 : (days + 29) ~/ 30;

/// What to put aside each month to reach the target on time, rounded up to the
/// cent. Null when there is nothing to put aside: the target is reached or the
/// date is today or past.
int? monthlyNeededFor(int remainingCents, int days) {
  final months = monthsLeft(days);
  if (remainingCents <= 0 || months == 0) return null;
  return (remainingCents + months - 1) ~/ months;
}

/// The status of a goal. Reaching the target wins over a date that passed.
GoalStatus goalStatusFor({
  required int savedCents,
  required int targetCents,
  required DateTime? targetDate,
  required DateTime today,
}) {
  if (savedCents >= targetCents) return GoalStatus.achieved;
  if (targetDate == null) return GoalStatus.open;
  return daysLeft(today, targetDate) < 0 ? GoalStatus.overdue : GoalStatus.onTrack;
}
