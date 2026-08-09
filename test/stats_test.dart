import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/stats.dart';

import 'helpers.dart';

/// The arithmetic is the one place where a wrong sign silently gives bad advice
/// all semester, so every branch is pinned here.
void main() {
  SubjectStats tally(int attended, int held, {int cancelled = 0}) => statsFor(
    stateWithTally(
      subjectId: 'os',
      attended: attended,
      held: held,
      cancelled: cancelled,
    ),
    'os',
  );

  group('current standing', () {
    test('exactly at 75% can miss nothing and needs nothing', () {
      final s = tally(30, 40);
      expect(s.percent, closeTo(0.75, 1e-9));
      expect(s.isAtTarget, isTrue);
      expect(s.canMissNow, 0);
      expect(s.mustAttendNow, 0);
    });

    test('87.5% can miss exactly 6 more', () {
      final s = tally(35, 40);
      expect(s.canMissNow, 6);
      // boundary either side of the answer
      expect(35 / 46, greaterThanOrEqualTo(0.75));
      expect(35 / 47, lessThan(0.75));
    });

    test('62.5% must attend the next 20 in a row', () {
      final s = tally(25, 40);
      expect(s.isAtTarget, isFalse);
      expect(s.mustAttendNow, 20);
      expect((25 + 20) / (40 + 20), closeTo(0.75, 1e-9));
      expect(s.canMissNow, 0, reason: 'never report a negative budget');
    });

    test('no classes held yet reports no percentage rather than 0 or 100', () {
      final s = tally(0, 0);
      expect(s.hasData, isFalse);
      expect(s.percent, isNull);
      expect(s.canMissNow, 0);
      expect(s.headline, 'No classes yet');
    });

    test('perfect attendance', () {
      final s = tally(12, 12);
      expect(s.percent, 1.0);
      expect(s.canMissNow, 4); // 12/16 = 75%
      expect(s.risk, RiskLevel.safe);
    });

    test('cancelled classes leave both numerator and denominator alone', () {
      final withCancels = tally(30, 40, cancelled: 8);
      final without = tally(30, 40);
      expect(withCancels.percent, without.percent);
      expect(withCancels.held, without.held);
      expect(withCancels.cancelled, 8);
    });
  });

  group('floating point does not cost you a class', () {
    // a / 0.75 lands on values like 39.999999999999996; a bare floor() would
    // under-report the budget by one.
    test('exact-boundary tallies round the right way', () {
      for (final (a, h, expected) in [
        (3, 4, 0),
        (6, 8, 0),
        (9, 12, 0),
        (15, 20, 0),
        (30, 40, 0),
        (60, 80, 0),
      ]) {
        expect(tally(a, h).canMissNow, expected, reason: '$a/$h');
      }
    });

    test('one above the boundary always yields at least one spare', () {
      expect(tally(31, 40).canMissNow, 1);
      expect(tally(16, 20).canMissNow, 1);
    });
  });

  group('risk banding', () {
    test('green at target + 5 points or better', () {
      expect(tally(80, 100).risk, RiskLevel.safe);
    });
    test('amber inside the last 5 points', () {
      expect(tally(77, 100).risk, RiskLevel.warning);
      expect(tally(75, 100).risk, RiskLevel.warning);
    });
    test('red below target', () {
      expect(tally(74, 100).risk, RiskLevel.danger);
    });
  });

  group('projections need a term end date', () {
    test('without an end date nothing is projected', () {
      final s = statsFor(
        stateWithTally(subjectId: 'os', attended: 30, held: 40),
        'os',
      );
      expect(s.remaining, isNull);
      expect(s.projectedTotal, isNull);
      expect(s.bestAchievable, isNull);
      expect(s.canMissRestOfTerm, isNull);
      expect(s.isTargetUnreachable, isFalse);
    });

    test('with remaining classes the whole-term budget is computed', () {
      const s = SubjectStats(
        subjectId: 'x',
        target: 0.75,
        attended: 30,
        held: 40,
        cancelled: 0,
        remaining: 20,
      );
      expect(s.projectedTotal, 60);
      expect(s.bestAchievable, closeTo(50 / 60, 1e-9));
      // 30 + 20 - 0.75*60 = 5
      expect(s.canMissRestOfTerm, 5);
      expect(s.isTargetUnreachable, isFalse);
    });

    test('an unreachable target says so instead of inventing a number', () {
      const s = SubjectStats(
        subjectId: 'x',
        target: 0.75,
        attended: 10,
        held: 40,
        cancelled: 0,
        remaining: 10,
      );
      expect(s.bestAchievable, closeTo(20 / 50, 1e-9));
      expect(s.isTargetUnreachable, isTrue);
      expect(s.canMissRestOfTerm, 0);
      expect(s.headline, contains('not reachable'));
      expect(s.headline, contains('40%'));
      // (0.75*50 - 20) / 0.25 = 70
      expect(s.extraClassesNeeded, 70);
    });
  });

  group('headline is one actionable sentence', () {
    test('safe', () => expect(tally(35, 40).headline, 'You can miss 6 more'));

    test(
      'no slack warns rather than congratulating',
      () => expect(tally(30, 40).headline, "Can't miss any right now"),
    );

    test('100% with no slack does not claim to be at the target', () {
      // 1/1 is 100% but a single absence drops it to 50%, so the budget is
      // zero — the message must not say "exactly at 75%".
      final s = tally(1, 1);
      expect(s.percent, 1.0);
      expect(s.canMissNow, 0);
      expect(s.headline, isNot(contains('75%')));
    });

    test(
      'below target',
      () => expect(tally(25, 40).headline, 'Attend next 20 to reach 75%'),
    );
  });
}
