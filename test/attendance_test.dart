import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/data/seed_tt.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/dates.dart';
import 'package:proxymate/logic/schedule.dart';
import 'package:proxymate/logic/stats.dart';
import 'package:proxymate/models/models.dart';

import 'helpers.dart';

void main() {
  // 6:00 pm Friday — the whole reference week has elapsed.
  final endOfWeek = DateTime(2026, 8, 7, 18, 0);

  group('catch-up backfills presence', () {
    test('a full elapsed week materialises 23 units as auto-present', () {
      final s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );

      final units = s.records.fold(0, (a, r) => a + r.units);
      expect(units, 23);
      expect(s.records.every((r) => r.status == Status.present), isTrue);
      expect(s.records.every((r) => !r.isManual), isTrue);
    });

    test('running it twice changes nothing', () {
      final once = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );
      final twice = catchUp(once, endOfWeek);
      expect(twice.records.length, once.records.length);
    });

    test('a class that has not ended yet is never marked', () {
      // Monday 9:00 am — period 1 (8:30-9:20) is still running.
      final s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        DateTime(2026, 8, 3, 9, 0),
      );
      expect(s.records, isEmpty);
    });

    test('mid-morning Monday captures only what has finished', () {
      // 10:25 am — periods 1 and 2 are done, period 3 (10:30) has not started.
      final s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        DateTime(2026, 8, 3, 10, 25),
      );
      expect(s.records.length, 2);
    });

    test('a week away backfills the whole gap on reopen', () {
      final s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        DateTime(2026, 8, 10, 8, 0), // the following Monday, before class
      );
      expect(s.records.fold(0, (a, r) => a + r.units), 23);
    });

    test('holidays generate nothing', () {
      var s = enrolledState().copyWith(lastGeneratedDate: monday);
      s = s.copyWith(term: s.term!.copyWith(holidays: {wednesday}));
      s = catchUp(s, endOfWeek);

      expect(s.records.any((r) => dateOnly(r.date) == wednesday), isFalse);
      expect(s.records.fold(0, (a, r) => a + r.units), 23 - 4);
    });

    test('dates past the term end generate nothing', () {
      var s = enrolledState(endDate: wednesday);
      s = s.copyWith(lastGeneratedDate: monday);
      s = catchUp(s, endOfWeek);

      expect(s.records.any((r) => dateOnly(r.date).isAfter(wednesday)), isFalse);
      expect(s.records.fold(0, (a, r) => a + r.units), 6 + 4 + 4);
    });

    test('an elective you did not take generates nothing', () {
      final s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );
      for (final notTaken in ['ai453', 'ai457', 'ai461', 'ai465', 'ai411']) {
        expect(
          s.records.any((r) => r.componentId.startsWith(notTaken)),
          isFalse,
          reason: notTaken,
        );
      }
    });

    test('no term configured means no generation at all', () {
      // seedClassTimetable() has courses and slots but no term yet, which is
      // exactly the state the app is in before setup finishes.
      final blank = seedClassTimetable().copyWith(
        enrolledCourseIds: defaultElectives,
        selectedBatch: 'Batch-I',
      );
      expect(blank.term, isNull);
      expect(catchUp(blank, endOfWeek).records, isEmpty);
    });
  });

  group('manual always wins', () {
    test('an absence marked before the class survives catch-up', () {
      var s = enrolledState().copyWith(lastGeneratedDate: monday);

      // Mark Monday's first class absent while it is still in the future.
      final occ = occurrencesOn(s, monday).first;
      s = setOccurrenceStatus(s, occ, Status.absent);
      expect(s.records.single.status, Status.absent);

      s = catchUp(s, endOfWeek);

      final kept = s.records.firstWhere((r) => r.slotId == occ.slot.id);
      expect(kept.status, Status.absent);
      expect(kept.isManual, isTrue);
      expect(s.records.where((r) => r.slotId == occ.slot.id).length, 1);
    });

    test('an absence marked after the fact is not reverted', () {
      var s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );

      final occ = occurrencesOn(s, monday).first;
      s = setOccurrenceStatus(s, occ, Status.absent);
      s = catchUp(s, DateTime(2026, 8, 14, 18, 0));

      expect(
        s.records.firstWhere((r) => r.slotId == occ.slot.id).status,
        Status.absent,
      );
    });

    test('marking absent moves only that component', () {
      var s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );

      final lab = occurrencesOn(
        s,
        thursday,
      ).firstWhere((o) => o.slot.componentId == 'ai451-lab');
      final theoryBefore = statsFor(s, 'ai451-th');

      s = setOccurrenceStatus(s, lab, Status.absent);

      final theoryAfter = statsFor(s, 'ai451-th');
      final labAfter = statsFor(s, 'ai451-lab');

      expect(theoryAfter.percent, theoryBefore.percent);
      expect(theoryAfter.held, theoryBefore.held);
      expect(labAfter.attended, 0);
      expect(labAfter.held, 2, reason: 'a 2-period lab weighs 2 units');
    });
  });

  group('teacher deviations', () {
    test('an extra class counts like any other record', () {
      var s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );
      final before = statsFor(s, 'ai401-th').held;

      s = addExtraClass(
        s,
        componentId: 'ai401-th',
        date: DateTime(2026, 8, 8), // a Saturday, not on the timetable
        note: 'makeup class',
      );

      expect(statsFor(s, 'ai401-th').held, before + 1);
      expect(s.records.last.slotId, isNull);
    });

    test('cancelling a whole day removes it from the denominator', () {
      var s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );
      final heldBefore = statsFor(s, 'ai401-th').held;

      s = markWholeDay(s, tuesday, Status.cancelled);

      // Tuesday carried one AI401 theory class.
      expect(statsFor(s, 'ai401-th').held, heldBefore - 1);
      expect(statsFor(s, 'ai401-th').cancelled, 1);
    });

    test('a no-class range clears records and blocks regeneration', () {
      var s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );
      expect(s.records, isNotEmpty);

      s = markRangeAsNoClass(s, wednesday, thursday);
      expect(
        s.records.any(
          (r) =>
              dateOnly(r.date) == wednesday || dateOnly(r.date) == thursday,
        ),
        isFalse,
      );

      // and a later catch-up must not put them back
      s = catchUp(s.copyWith(lastGeneratedDate: monday), endOfWeek);
      expect(
        s.records.any((r) => dateOnly(r.date) == wednesday),
        isFalse,
      );
    });

    test('deleting a record removes it from the tally', () {
      var s = catchUp(
        enrolledState().copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );
      final target = s.records.first;
      final before = statsFor(s, target.componentId).held;

      s = deleteRecord(s, target.id);
      expect(statsFor(s, target.componentId).held, before - target.units);
    });
  });

  group('two sessions of one subject in a day stay independent', () {
    test('AI411 Thursday: present for one, absent for the other', () {
      var s = catchUp(
        enrolledState(honours: true).copyWith(lastGeneratedDate: monday),
        endOfWeek,
      );

      final thu = occurrencesOn(
        s,
        thursday,
      ).where((o) => o.slot.componentId == 'ai411-th').toList();
      expect(thu.length, 2);

      s = setOccurrenceStatus(s, thu.first, Status.absent);

      final records = s.records
          .where(
            (r) => r.componentId == 'ai411-th' && dateOnly(r.date) == thursday,
          )
          .toList();

      expect(records.length, 2);
      expect(records.where((r) => r.status == Status.absent).length, 1);
      expect(records.where((r) => r.status == Status.present).length, 1);
    });
  });
}
