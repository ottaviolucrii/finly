import 'package:equatable/equatable.dart';
import 'package:finly/features/lock/domain/attempt_limiter.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';

/// The outcome of checking the account password for a protected action (the
/// lock screen or a workspace switch).
class PasswordCheckResult extends Equatable {
  /// [LockError.none] means the password was right.
  final LockError error;

  /// Wrong passwords left before the block.
  final int attemptsLeft;

  /// When the block ends, if there is one.
  final DateTime? blockedUntil;

  const PasswordCheckResult({
    this.error = LockError.none,
    this.attemptsLeft = AttemptLimiter.maxFailures,
    this.blockedUntil,
  });

  bool get ok => error == LockError.none;

  @override
  List<Object?> get props => [error, attemptsLeft, blockedUntil];
}
