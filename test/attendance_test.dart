import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/schedule.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';

import 'helpers.dart';

/// The two invariants that make "don't open the app for a week" correct:
/// generation only ever inserts where nothing exists, and only for classes that
/// have already ended.
void main() {
  // Monday evening, after everything including the untimed seminar (18:00).
  final mondayNight = DateTime(2026, 8, 3, 22);

  group('catch-up', () {
    test('marks every elapsed class present', () {
      final s = catchUp(testState(), mondayNight);
      expect(s.records, hasLength(4));
      expect(s.records.every((r) => r.status == Status.present), isTrue);
      expect(s.records.every((r) => !r.isManual), isTrue);
    });

    test('does not mark a class that has not ended yet', () {
      // 10:30 — only Maths 9:00-9:50 has finished. OS runs to 10:50, Maths
      // again at 14:00, and the untimed seminar settles at 18:00.
      final s = catchUp(testState(), DateTime(2026, 8, 3, 10, 30));
      expect(s.records, hasLength(1));
      expect(s.records.single.slotId, 's1');
    });

    test('a class is marked the minute it ends, not a moment before', () {
      final justBefore = catchUp(testState(), DateTime(2026, 8, 3, 10, 49));
      expect(justBefore.records.any((r) => r.slotId == 's2'), isFalse);

      final justAfter = catchUp(testState(), DateTime(2026, 8, 3, 10, 50));
      expect(justAfter.records.any((r) => r.slotId == 's2'), isTrue);
    });

    test('an untimed class waits for the end-of-day time', () {
      final before = catchUp(testState(), DateTime(2026, 8, 3, 17, 59));
      expect(before.records.any((r) => r.slotId == 's4'), isFalse);

      final after = catchUp(testState(), DateTime(2026, 8, 3, 18, 1));
      expect(after.records.any((r) => r.slotId == 's4'), isTrue);
    });

    test('a manual absence is never overwritten', () {
      final marked = testState(
        records: [rec('maths', monday, Status.absent, slotId: 's1', manual: true)],
      );
      final s = catchUp(marked, mondayNight);

      final s1 = s.records.where((r) => r.slotId == 's1');
      expect(s1, hasLength(1), reason: 'no duplicate was inserted');
      expect(s1.single.status, Status.absent);
      expect(s1.single.isManual, isTrue);
    });

    test('a week away backfills exactly the right classes', () {
      // Mon 3 Aug through Sun 9 Aug: Mon 4, Tue 1, Wed 1 = 6.
      final s = catchUp(testState(), DateTime(2026, 8, 9, 23));
      expect(s.records, hasLength(6));
    });

    test('running twice adds nothing the second time', () {
      final once = catchUp(testState(), mondayNight);
      final twice = catchUp(once, mondayNight);
      expect(twice.records, hasLength(once.records.length));
      expect(identical(twice, once), isTrue, reason: 'no pointless rewrite');
    });

    test('holidays and post-term dates generate nothing', () {
      var s = testState(end: monday);
      s = s.copyWith(term: s.term!.copyWith(holidays: {monday}));
      expect(catchUp(s, mondayNight).records, isEmpty);
    });

    test('no term means nothing happens at all', () {
      expect(catchUp(const AppState(), mondayNight).records, isEmpty);
    });
  });

  group('marking', () {
    test('marking a future class writes a manual record catch-up respects', () {
      final morning = DateTime(2026, 8, 3, 8);
      final occ = occurrencesOn(testState(), monday).firstWhere(
        (o) => o.slot.id == 's3', // Maths 14:00, hasn't happened
      );

      var s = setOccurrenceStatus(testState(), occ, Status.absent);
      expect(s.records.single.isManual, isTrue);

      s = catchUp(s, morning);
      expect(s.records.where((r) => r.slotId == 's3'), hasLength(1));
      expect(s.records.firstWhere((r) => r.slotId == 's3').status,
          Status.absent);
    });

    test('two entries of one subject on one day are independent', () {
      var s = catchUp(testState(), mondayNight);
      final maths = occurrencesOn(s, monday)
          .where((o) => o.slot.subjectId == 'maths')
          .toList();

      s = setOccurrenceStatus(s, maths.first, Status.absent);

      final records = s.records.where((r) => r.subjectId == 'maths').toList();
      expect(records, hasLength(2));
      expect(records.map((r) => r.status).toSet(),
          {Status.absent, Status.present});
    });

    test('an extra class counts even with no slot behind it', () {
      final s = addExtraClass(
        testState(),
        subjectId: 'os',
        date: monday,
        status: Status.present,
      );
      expect(s.records.single.slotId, isNull);
      expect(s.records.single.isManual, isTrue);
    });

    test('marking a whole day cancelled touches every class on it', () {
      final s = markWholeDay(testState(), monday, Status.cancelled);
      expect(s.records, hasLength(4));
      expect(s.records.every((r) => r.status == Status.cancelled), isTrue);
    });

    test('a no-class range clears records and blocks regeneration', () {
      var s = catchUp(testState(), mondayNight);
      expect(s.records, isNotEmpty);

      s = markRangeAsNoClass(s, monday, monday.add(const Duration(days: 2)));
      expect(s.records, isEmpty);

      s = catchUp(s, DateTime(2026, 8, 5, 23));
      expect(s.records, isEmpty, reason: 'the range is now a holiday');
    });
  });

  group('deleting a subject', () {
    test('its slots stop generating', () {
      final s = testState(subjects: [subOs, subOsLab, subSeminar]);
      final generated = catchUp(s, mondayNight);
      expect(
        generated.records.any((r) => r.subjectId == 'maths'),
        isFalse,
      );
    });
  });
}
