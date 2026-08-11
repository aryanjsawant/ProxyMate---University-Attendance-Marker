import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/notifications.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';

import 'helpers.dart';

/// The scheduling decisions, tested without the platform.
///
/// This file exists because notifications are the one part of the app whose
/// failure mode is *silence* — nothing crashes, the user simply never hears
/// from it — and it previously had no tests at all.
void main() {
  NudgePlan? planFor(AppState s, int weekday) {
    final plans = buildNudgePlans(s).where((p) => p.weekday == weekday);
    return plans.isEmpty ? null : plans.first;
  }

  group('when the nudge fires', () {
    test('30 minutes after the last class of that day', () {
      // Monday's last timed class ends 14:50, but the untimed seminar pushes
      // the day out to the 18:00 end-of-day.
      final p = planFor(testState(), DateTime.monday)!;
      expect(p.minuteOfDay, 18 * 60 + 30);
    });

    test('a day with only timed classes uses the real last end', () {
      // Tuesday: one class, 09:00-09:50.
      final p = planFor(testState(), DateTime.tuesday)!;
      expect(p.minuteOfDay, at(9, 50) + 30);
    });

    test('the end-of-day setting moves untimed days', () {
      final s = testState(dayEndsAt: 21 * 60);
      expect(planFor(s, DateTime.monday)!.minuteOfDay, 21 * 60 + 30);
      // Tuesday has no untimed class, so it is unaffected.
      expect(planFor(s, DateTime.tuesday)!.minuteOfDay, at(9, 50) + 30);
    });

    test('the offset setting is respected', () {
      var s = testState();
      s = s.copyWith(
        settings: s.settings.copyWith(nudgeOffsetMinutes: 0),
      );
      expect(planFor(s, DateTime.tuesday)!.minuteOfDay, at(9, 50));
    });

    test('a late finish clamps to 23:59 instead of wrapping to the morning', () {
      // Regression: (fireAt ~/ 60) % 24 used to turn 23:00 + 120 into 01:00 on
      // the same weekday — the reminder arriving 22 hours before the classes.
      var s = testState(
        slots: [
          Slot(
            id: 'late',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(22),
            endMin: at(23),
          ),
        ],
      );
      s = s.copyWith(
        settings: s.settings.copyWith(nudgeOffsetMinutes: 120),
      );

      final p = planFor(s, DateTime.monday)!;
      expect(p.hour, 23);
      expect(p.minute, 59);
      expect(
        p.minuteOfDay,
        greaterThan(at(23)),
        reason: 'must never land before the classes it summarises',
      );
    });
  });

  group('which days get one', () {
    test('only days that actually have classes', () {
      final days = buildNudgePlans(testState()).map((p) => p.weekday).toSet();
      expect(days, {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
      });
    });

    test('an empty timetable schedules nothing', () {
      expect(buildNudgePlans(testState(slots: const [])), isEmpty);
    });

    test('a day whose only subject was deleted schedules nothing', () {
      // Wednesday's sole class is the OS lab.
      final s = testState(subjects: [subOs, subMaths, subSeminar]);
      expect(planFor(s, DateTime.wednesday), isNull);
    });

    test('never more than one per weekday', () {
      final plans = buildNudgePlans(testState());
      expect(
        plans.map((p) => p.weekday).toSet().length,
        plans.length,
        reason: 'duplicate ids would overwrite each other anyway',
      );
    });
  });

  group('what it says', () {
    test('states the number of classes scheduled, not what was recorded', () {
      // Monday has four entries: Maths, OS, Maths again, and the seminar.
      final p = planFor(testState(), DateTime.monday)!;
      expect(p.title, 'You had 4 classes today');
      expect(p.body, contains('Tap to fix'));
    });

    test('never claims an attendance outcome', () {
      // The text is frozen at schedule time and fires with the app not
      // running, so any such claim would be a guess.
      for (final p in buildNudgePlans(testState())) {
        expect(p.title.toLowerCase(), isNot(contains('present')));
        expect(p.title.toLowerCase(), isNot(contains('absent')));
        expect(p.title.toLowerCase(), isNot(contains('marked')));
      }
    });

    test('singular for a single class', () {
      final p = planFor(testState(), DateTime.tuesday)!;
      expect(p.title, 'You had 1 class today');
    });

    test('the count follows the timetable, not the records', () {
      // Marking absences must not change what is scheduled.
      final marked = testState(
        records: [
          rec('maths', monday, Status.absent, slotId: 's1', manual: true),
          rec('os', monday, Status.absent, slotId: 's2', manual: true),
        ],
      );
      expect(planFor(marked, DateTime.monday)!.title, 'You had 4 classes today');
    });
  });
}
