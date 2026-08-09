import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/schedule.dart';

import 'helpers.dart';

/// These lock in the transcription of the printed class timetable. If someone
/// edits `seed_tt.dart` and one of these breaks, the seed no longer matches the
/// sheet it came from.
void main() {
  test('the reference week really starts on a Monday', () {
    expect(monday.weekday, DateTime.monday);
    expect(friday.weekday, DateTime.friday);
  });

  group('weekly load', () {
    int unitsOn(DateTime day, {bool honours = false}) {
      final s = enrolledState(honours: honours);
      return occurrencesOn(
        s,
        day,
      ).fold(0, (sum, o) => sum + o.slot.units);
    }

    test('non-honours student has 23 periods a week', () {
      expect(unitsOn(monday), 6, reason: '4 lectures + a 2-period IMAES lab');
      expect(unitsOn(tuesday), 4);
      expect(unitsOn(wednesday), 4);
      expect(unitsOn(thursday), 4, reason: 'two 2-period labs, no lectures');
      expect(unitsOn(friday), 5);

      final total = [monday, tuesday, wednesday, thursday, friday]
          .map((d) => unitsOn(d))
          .fold(0, (a, b) => a + b);
      expect(total, 23);
    });

    test('adding honours AI411 makes it 27', () {
      final total = [monday, tuesday, wednesday, thursday, friday]
          .map((d) => unitsOn(d, honours: true))
          .fold(0, (a, b) => a + b);
      expect(total, 27);
    });
  });

  group('credit lines match L-T-P', () {
    List<Occurrence> weekFor(String componentId, {Set<String>? courseIds}) {
      final s = enrolledState(courseIds: courseIds ?? defaultElectives);
      return expandSlots(s, monday, friday)
          .where((o) => o.slot.componentId == componentId)
          .toList();
    }

    test('AI401 IMAES is 3 theory + a 2-period lab', () {
      expect(weekFor('ai401-th').length, 3);
      final lab = weekFor('ai401-lab');
      expect(lab.length, 1);
      expect(lab.single.slot.units, 2);
    });

    test('AI455 IR is 3-1-0: three lectures and one tutorial', () {
      final w = weekFor('ai455-th');
      expect(w.length, 4);
      expect(w.where((o) => o.slot.isTutorial).length, 1);
      expect(w.where((o) => !o.slot.isTutorial).length, 3);
    });

    test('AI451 AC is 3 theory + a 2-period lab', () {
      expect(weekFor('ai451-th').length, 3);
      expect(weekFor('ai451-lab').single.slot.units, 2);
    });

    test('AI463 ILLM is 3 theory + a 2-period lab', () {
      expect(weekFor('ai463-th').length, 3);
      expect(weekFor('ai463-lab').single.slot.units, 2);
    });

    test('honours AI411 is four sessions, one of them a tutorial', () {
      final s = enrolledState(honours: true);
      final w = expandSlots(s, monday, friday)
          .where((o) => o.slot.componentId == 'ai411-th')
          .toList();
      expect(w.length, 4);
      expect(w.where((o) => o.slot.isTutorial).length, 1);
    });
  });

  group('tutorial polarity in slot D', () {
    // Monday's D slot is a lecture for AI459 but a tutorial for AI461, and
    // Tuesday is the reverse. Both still land on 3L + 1T.
    Occurrence dOn(DateTime day, String componentId, Set<String> courseIds) {
      final s = enrolledState(courseIds: courseIds);
      return occurrencesOn(
        s,
        day,
      ).firstWhere((o) => o.slot.componentId == componentId);
    }

    const withAifs = {'ai401', 'ai451', 'ai455', 'ai459', 'ai463'};
    const withAbss = {'ai401', 'ai451', 'ai455', 'ai461', 'ai463'};

    test('AI459 has Monday lecture, Tuesday tutorial', () {
      expect(dOn(monday, 'ai459-th', withAifs).slot.isTutorial, isFalse);
      expect(dOn(tuesday, 'ai459-th', withAifs).slot.isTutorial, isTrue);
    });

    test('AI461 is the exact reverse', () {
      expect(dOn(monday, 'ai461-th', withAbss).slot.isTutorial, isTrue);
      expect(dOn(tuesday, 'ai461-th', withAbss).slot.isTutorial, isFalse);
    });

    test('each still totals 3 lectures + 1 tutorial', () {
      for (final (comp, ids) in [
        ('ai459-th', withAifs),
        ('ai461-th', withAbss),
      ]) {
        final w = expandSlots(enrolledState(courseIds: ids), monday, friday)
            .where((o) => o.slot.componentId == comp);
        expect(w.length, 4, reason: comp);
        expect(w.where((o) => o.slot.isTutorial).length, 1, reason: comp);
      }
    });
  });

  group('electives filter the shared class timetable', () {
    test('switching slot C from IR to IoT keeps four meetings', () {
      final ir = expandSlots(
        enrolledState(courseIds: {'ai401', 'ai451', 'ai455', 'ai459', 'ai463'}),
        monday,
        friday,
      ).where((o) => o.slot.componentId == 'ai455-th');

      final iot = expandSlots(
        enrolledState(courseIds: {'ai401', 'ai451', 'ai457', 'ai459', 'ai463'}),
        monday,
        friday,
      ).where((o) => o.slot.componentId == 'ai457-th');

      expect(ir.length, 4);
      expect(iot.length, 4);
    });

    test('the elective you did not take generates nothing', () {
      final week = expandSlots(enrolledState(), monday, friday);
      for (final unchosen in ['ai453', 'ai457', 'ai461', 'ai465', 'ai411']) {
        expect(
          week.where((o) => o.slot.componentId.startsWith(unchosen)),
          isEmpty,
          reason: '$unchosen was not enrolled',
        );
      }
    });

    test('weekly load is unchanged by which side of each pair you pick', () {
      final a = expandSlots(
        enrolledState(courseIds: {'ai401', 'ai451', 'ai455', 'ai459', 'ai463'}),
        monday,
        friday,
      ).fold(0, (s, o) => s + o.slot.units);

      final b = expandSlots(
        enrolledState(courseIds: {'ai401', 'ai453', 'ai457', 'ai461', 'ai465'}),
        monday,
        friday,
      ).fold(0, (s, o) => s + o.slot.units);

      expect(a, 23);
      expect(b, 23);
    });
  });

  group('lab batches', () {
    test('Batch-I gets the 2:00 Monday IMAES lab', () {
      final occ = occurrencesOn(enrolledState(batch: 'Batch-I'), monday)
          .firstWhere((o) => o.slot.componentId == 'ai401-lab');
      expect(occ.startPeriod.index, 5);
      expect(occ.slot.units, 2);
    });

    test('Batch-II gets the 4:00 one instead', () {
      final occ = occurrencesOn(enrolledState(batch: 'Batch-II'), monday)
          .firstWhere((o) => o.slot.componentId == 'ai401-lab');
      expect(occ.startPeriod.index, 7);
    });

    test('a student only ever sees one of the two', () {
      for (final b in ['Batch-I', 'Batch-II']) {
        final labs = occurrencesOn(enrolledState(batch: b), monday)
            .where((o) => o.slot.componentId == 'ai401-lab');
        expect(labs.length, 1, reason: b);
      }
    });
  });

  group('the caveats other apps get wrong', () {
    test('AI411 runs twice on Thursday as two independent occurrences', () {
      final s = enrolledState(honours: true);
      final thu = occurrencesOn(
        s,
        thursday,
      ).where((o) => o.slot.componentId == 'ai411-th').toList();

      expect(thu.length, 2);
      expect(thu[0].slot.id, isNot(thu[1].slot.id));
      expect(thu[0].startPeriod.index, 7);
      expect(thu[1].startPeriod.index, 8);
    });

    test('a 2-period lab spans both periods and counts 2 units', () {
      final lab = occurrencesOn(enrolledState(), thursday)
          .firstWhere((o) => o.slot.componentId == 'ai451-lab');

      expect(lab.startPeriod.index, 1);
      expect(lab.endPeriod.index, 2);
      expect(lab.slot.units, 2);
      // 8:30 -> 10:20
      expect(lab.startsAt.hour, 8);
      expect(lab.startsAt.minute, 30);
      expect(lab.endsAt.hour, 10);
      expect(lab.endsAt.minute, 20);
    });

    test('occurrences come back in chronological order', () {
      final day = occurrencesOn(enrolledState(), friday);
      for (var i = 1; i < day.length; i++) {
        expect(
          day[i].startPeriod.startMin >= day[i - 1].startPeriod.startMin,
          isTrue,
        );
      }
    });
  });

  test('weekends are empty', () {
    final s = enrolledState(honours: true);
    expect(occurrencesOn(s, DateTime(2026, 8, 8)), isEmpty); // Saturday
    expect(occurrencesOn(s, DateTime(2026, 8, 9)), isEmpty); // Sunday
  });
}
