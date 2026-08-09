import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/schedule.dart';
import 'package:proxymate/models/models.dart';

import 'helpers.dart';

void main() {
  group('expansion', () {
    test('a subject meeting twice in one day produces two occurrences', () {
      final occ = occurrencesOn(testState(), monday);
      final maths = occ.where((o) => o.slot.subjectId == 'maths').toList();
      expect(maths, hasLength(2));
      expect(maths[0].slot.id, isNot(maths[1].slot.id));
    });

    test('timed classes come first, in time order; untimed last', () {
      final occ = occurrencesOn(testState(), monday);
      expect(
        occ.map((o) => o.slot.id).toList(),
        ['s1', 's2', 's3', 's4'],
        reason: 'the untimed seminar sorts after every timed class',
      );
    });

    test('monday has four classes, tuesday one, thursday none', () {
      final s = testState();
      expect(occurrencesOn(s, monday), hasLength(4));
      expect(
        occurrencesOn(s, monday.add(const Duration(days: 1))),
        hasLength(1),
      );
      expect(
        occurrencesOn(s, monday.add(const Duration(days: 3))),
        isEmpty,
      );
    });

    test('nothing is scheduled before the term starts', () {
      final s = testState(start: monday.add(const Duration(days: 7)));
      expect(occurrencesOn(s, monday), isEmpty);
    });

    test('holidays generate nothing', () {
      var s = testState();
      s = s.copyWith(
        term: s.term!.copyWith(holidays: {monday}),
      );
      expect(occurrencesOn(s, monday), isEmpty);
    });

    test('a slot whose subject was deleted is skipped', () {
      final s = testState(subjects: [subOs, subOsLab, subSeminar]);
      final occ = occurrencesOn(s, monday);
      expect(occ.any((o) => o.slot.subjectId == 'maths'), isFalse);
      expect(occ, hasLength(2)); // OS 10:00 + untimed seminar
    });
  });

  group('when a class counts as over', () {
    test('a timed class elapses at its end time', () {
      final occ = occurrencesOn(testState(), monday).first; // Maths 9:00-9:50
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 9, 49)), isFalse);
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 9, 50)), isTrue);
    });

    test('an untimed class elapses at the configured end of day', () {
      final occ = occurrencesOn(
        testState(),
        monday,
      ).firstWhere((o) => o.slot.id == 's4');

      expect(occ.isTimed, isFalse);
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 17, 59)), isFalse);
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 18, 0)), isTrue);
    });

    test('changing the end-of-day setting moves when untimed classes settle', () {
      final occ = occurrencesOn(
        testState(dayEndsAt: 21 * 60),
        monday,
      ).firstWhere((o) => o.slot.id == 's4');

      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 18, 0)), isFalse);
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 21, 0)), isTrue);
    });

    test('a class with a start but no end elapses at its start', () {
      final s = testState(
        slots: [
          Slot(
            id: 'x',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(11),
          ),
        ],
      );
      final occ = occurrencesOn(s, monday).single;
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 10, 59)), isFalse);
      expect(occ.hasElapsedAt(DateTime(2026, 8, 3, 11, 0)), isTrue);
    });
  });

  group('counting', () {
    test('a two-hour class is still one attendance', () {
      final wed = monday.add(const Duration(days: 2));
      final s = catchUp(testState(), DateTime(2026, 8, 5, 23, 0));
      final labRecords = s.records.where((r) => r.subjectId == 'oslab');

      expect(labRecords, hasLength(1));
      expect(labRecords.single.units, 1);
      expect(labRecords.single.date, wed);
    });

    test('weeklyUnits counts entries, not hours', () {
      final s = testState();
      expect(weeklyUnits(s, 'maths'), 2); // twice on Monday
      expect(weeklyUnits(s, 'os'), 2); // Mon + Tue
      expect(weeklyUnits(s, 'oslab'), 1); // one two-hour block
    });

    test('remaining counts every future entry once', () {
      final s = testState(end: monday.add(const Duration(days: 6)));
      final remaining = remainingUnitsBySubject(s, monday);
      expect(remaining['maths'], 2);
      expect(remaining['os'], 2);
      expect(remaining['oslab'], 1);
      expect(remaining['sem'], 1);
    });
  });
}
