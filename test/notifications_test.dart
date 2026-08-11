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
///
/// The default fixture is a Batch-I student without honours: IMAES, Affective
/// Computing, Information Retrieval, AI for Sustainability, Intro to LLMs.
void main() {
  NudgePlan? planFor(AppState s, int weekday) {
    final plans = buildNudgePlans(s).where((p) => p.weekday == weekday);
    return plans.isEmpty ? null : plans.first;
  }

  const nudgeOffset = 30;

  group('when the nudge fires', () {
    test('after the Monday IMAES lab, which ends 15:50 for Batch-I', () {
      final p = planFor(enrolledState(), DateTime.monday)!;
      expect(p.minuteOfDay, 15 * 60 + 50 + nudgeOffset);
    });

    test('Batch-II ends later, so their Monday nudge is later', () {
      final p = planFor(enrolledState(batch: 'Batch-II'), DateTime.monday)!;
      expect(p.minuteOfDay, 17 * 60 + 50 + nudgeOffset);
    });

    test('a morning-only day fires just after noon', () {
      // Thursday is the two lab blocks, the last ending 12:20.
      final p = planFor(enrolledState(), DateTime.thursday)!;
      expect(p.minuteOfDay, 12 * 60 + 20 + nudgeOffset);
    });

    test('honours pushes Thursday and Friday out to the 17:50 finish', () {
      final s = enrolledState(honours: true);
      expect(planFor(s, DateTime.thursday)!.minuteOfDay,
          17 * 60 + 50 + nudgeOffset);
      expect(planFor(s, DateTime.friday)!.minuteOfDay,
          17 * 60 + 50 + nudgeOffset);
    });

    test('the offset setting is respected', () {
      var s = enrolledState();
      s = s.copyWith(settings: s.settings.copyWith(nudgeOffsetMinutes: 0));
      expect(planFor(s, DateTime.thursday)!.minuteOfDay, 12 * 60 + 20);
    });

    test('a long delay clamps to 23:59 instead of wrapping to the morning', () {
      // Regression: (fireAt ~/ 60) % 24 rolled a late finish past midnight
      // back onto the small hours of the *same* weekday, so the reminder
      // arrived before the classes it summarises.
      var s = enrolledState();
      s = s.copyWith(settings: s.settings.copyWith(nudgeOffsetMinutes: 600));

      final p = planFor(s, DateTime.monday)!;
      expect(p.hour, 23);
      expect(p.minute, 59);
      expect(p.minuteOfDay, greaterThan(15 * 60 + 50));
    });
  });

  group('which days get one', () {
    test('all five weekdays, never the weekend', () {
      final days =
          buildNudgePlans(enrolledState()).map((p) => p.weekday).toSet();
      expect(days, {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      });
    });

    test('an empty timetable schedules nothing', () {
      expect(
        buildNudgePlans(enrolledState().copyWith(slots: const [])),
        isEmpty,
      );
    });

    test('never more than one per weekday', () {
      final plans = buildNudgePlans(enrolledState());
      expect(
        plans.map((p) => p.weekday).toSet().length,
        plans.length,
        reason: 'duplicate ids would overwrite each other anyway',
      );
    });
  });

  group('what it says', () {
    test('counts classes, so a two-period lab counts once', () {
      // Thursday is two lab blocks spanning four periods — two classes.
      expect(
        planFor(enrolledState(), DateTime.thursday)!.title,
        'You had 2 classes today',
      );
    });

    test('Monday is four lectures plus one lab', () {
      expect(
        planFor(enrolledState(), DateTime.monday)!.title,
        'You had 5 classes today',
      );
    });

    test('never claims an attendance outcome', () {
      // The text is frozen at schedule time and fires with the app not
      // running, so any such claim is a guess. This is the reported bug:
      // "marked you present for 4 classes" after absences had been set.
      for (final p in buildNudgePlans(enrolledState(honours: true))) {
        expect(p.title.toLowerCase(), isNot(contains('present')));
        expect(p.title.toLowerCase(), isNot(contains('absent')));
        expect(p.title.toLowerCase(), isNot(contains('marked')));
      }
    });

    test('the count follows the timetable, not what was recorded', () {
      final marked = enrolledState().copyWith(
        records: [
          AttendanceRecord(
            id: 'x1',
            componentId: 'ai455-th',
            date: monday,
            slotId: 'm1-455',
            status: Status.absent,
            units: 1,
            isManual: true,
          ),
        ],
      );
      expect(
        planFor(marked, DateTime.monday)!.title,
        planFor(enrolledState(), DateTime.monday)!.title,
      );
    });
  });
}
