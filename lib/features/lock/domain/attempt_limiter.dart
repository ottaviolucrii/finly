import 'package:equatable/equatable.dart';

/// Brute-force protection for the password prompt (SRS FR-A09): after
/// [maxFailures] wrong passwords, further attempts are blocked for
/// [blockDuration]. It is only a value: the clock is always passed in.
class AttemptLimiter extends Equatable {
  static const maxFailures = 5;
  static const blockDuration = Duration(minutes: 5);

  /// Wrong passwords since the last success or the last block.
  final int failures;

  /// When the block ends, if there is one.
  final DateTime? blockedUntil;

  const AttemptLimiter({this.failures = 0, this.blockedUntil});

  bool isBlocked(DateTime now) {
    final until = blockedUntil;
    return until != null && now.isBefore(until);
  }

  /// How long the block still lasts (zero when there is none).
  Duration remaining(DateTime now) {
    final until = blockedUntil;
    if (until == null || !now.isBefore(until)) return Duration.zero;
    return until.difference(now);
  }

  /// Attempts left before the block.
  int get attemptsLeft => maxFailures - failures;

  /// Counts one wrong password. The fifth starts the block. While blocked,
  /// nothing changes.
  AttemptLimiter recordFailure(DateTime now) {
    if (isBlocked(now)) return this;

    final next = failures + 1;
    if (next >= maxFailures) {
      return AttemptLimiter(blockedUntil: now.add(blockDuration));
    }
    return AttemptLimiter(failures: next);
  }

  @override
  List<Object?> get props => [failures, blockedUntil];
}