import 'package:finly/features/lock/domain/attempt_limiter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 6, 12);

  AttemptLimiter failTimes(int times, {DateTime? at}) {
    var limiter = const AttemptLimiter();
    for (var i = 0; i < times; i++) {
      limiter = limiter.recordFailure(at ?? start);
    }
    return limiter;
  }

  test('starts free, with all the attempts', () {
    const limiter = AttemptLimiter();

    expect(limiter.isBlocked(start), isFalse);
    expect(limiter.attemptsLeft, 5);
    expect(limiter.remaining(start), Duration.zero);
  });

  test('counts the wrong passwords', () {
    final limiter = failTimes(3);

    expect(limiter.failures, 3);
    expect(limiter.attemptsLeft, 2);
    expect(limiter.isBlocked(start), isFalse);
  });

  test('the fifth wrong password blocks for five minutes', () {
    final limiter = failTimes(5);

    expect(limiter.isBlocked(start), isTrue);
    expect(limiter.blockedUntil, start.add(const Duration(minutes: 5)));
    expect(limiter.remaining(start), const Duration(minutes: 5));
  });

  test('the block lasts until exactly five minutes pass', () {
    final limiter = failTimes(5);

    expect(limiter.isBlocked(start.add(const Duration(minutes: 4, seconds: 59))), isTrue);
    expect(limiter.isBlocked(start.add(const Duration(minutes: 5))), isFalse);
    expect(
      limiter.remaining(start.add(const Duration(minutes: 3))),
      const Duration(minutes: 2),
    );
  });

  test('a wrong password during the block changes nothing', () {
    final blocked = failTimes(5);

    final again = blocked.recordFailure(start.add(const Duration(minutes: 1)));

    expect(again, blocked);
  });

  test('after the block, the count starts again from zero', () {
    final blocked = failTimes(5);
    final later = start.add(const Duration(minutes: 6));

    final next = blocked.recordFailure(later);

    expect(next.failures, 1);
    expect(next.blockedUntil, isNull);
    expect(next.attemptsLeft, 4);
    expect(next.isBlocked(later), isFalse);
  });

  test('a limiter with the same values is equal', () {
    expect(failTimes(2), failTimes(2));
    expect(failTimes(2), isNot(failTimes(3)));
  });
}