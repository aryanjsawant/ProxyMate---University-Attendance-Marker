import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/dates.dart';
import 'package:proxymate/logic/schedule.dart';
import 'package:proxymate/logic/stats.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';
import 'package:proxymate/state/providers.dart';

import 'helpers.dart';

/// Adding and removing subjects is the operation most likely to leave the app
/// in a broken half-state: orphaned timetable entries, records that still count
/// towards a subject you can no longer see, screens that crash on a dangling
/// id. Every one of those is pinned here.
void main() {
  // Riverpod commits write through Store, which touches path_provider.
  TestWidgetsFlutterBinding.ensureInitialized();

  final mondayNight = DateTime(2026, 8, 3, 22);

  ProviderContainer containerWith(AppState s) {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appProvider.notifier).applyImportedTimetable(s);
    return c;
  }

  group('deleting a subject', () {
    test('removes the subject, its timetable entries and its history', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      expect(c.read(appProvider).records.where((r) => r.subjectId == 'maths'),
          hasLength(2));

      c.read(appProvider.notifier).deleteSubject('maths');
      final s = c.read(appProvider);

      expect(s.subjectById('maths'), isNull);
      expect(s.slots.where((x) => x.subjectId == 'maths'), isEmpty);
      expect(s.records.where((r) => r.subjectId == 'maths'), isEmpty);
    });

    test('leaves every other subject completely untouched', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      final before = {
        for (final id in ['os', 'oslab', 'sem'])
          id: statsFor(c.read(appProvider), id),
      };

      c.read(appProvider.notifier).deleteSubject('maths');

      for (final id in ['os', 'oslab', 'sem']) {
        final after = statsFor(c.read(appProvider), id);
        expect(after.attended, before[id]!.attended, reason: id);
        expect(after.held, before[id]!.held, reason: id);
      }
    });

    test('it disappears from the stats list rather than lingering at 0%', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      c.read(appProvider.notifier).deleteSubject('maths');

      final ids = allStats(c.read(appProvider)).map((s) => s.subjectId);
      expect(ids, isNot(contains('maths')));
      expect(ids, hasLength(3));
    });

    test('deleting every subject leaves a coherent empty app', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      for (final id in ['os', 'maths', 'oslab', 'sem']) {
        c.read(appProvider.notifier).deleteSubject(id);
      }

      final s = c.read(appProvider);
      expect(s.subjects, isEmpty);
      expect(s.slots, isEmpty);
      expect(s.records, isEmpty);
      expect(s.hasSubjects, isFalse);
      expect(s.hasTimetable, isFalse);
      expect(allStats(s), isEmpty);
      expect(occurrencesOn(s, monday), isEmpty);
      // Still configured — the term survives, so the app doesn't bounce the
      // user back into onboarding.
      expect(s.isConfigured, isTrue);
    });

    test('catch-up after a delete does not resurrect anything', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      c.read(appProvider.notifier).deleteSubject('maths');

      final revived = catchUp(c.read(appProvider), mondayNight);
      expect(revived.records.any((r) => r.subjectId == 'maths'), isFalse);
    });

    test('an orphaned slot is ignored instead of crashing expansion', () {
      // Simulates a hand-edited or partially-migrated import.
      final broken = testState().copyWith(
        subjects: [subOs],
      );
      expect(() => occurrencesOn(broken, monday), returnsNormally);
      expect(occurrencesOn(broken, monday), hasLength(1));
      expect(broken.activeSlots, hasLength(2)); // OS on Mon and Tue
    });
  });

  group('adding and editing subjects', () {
    test('a new subject starts clean and does not disturb others', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      final osBefore = statsFor(c.read(appProvider), 'os');

      c.read(appProvider.notifier).upsertSubject(
            const Subject(id: 'new', name: 'Compilers', color: 0xFF123456),
          );

      final s = c.read(appProvider);
      expect(statsFor(s, 'new').hasData, isFalse);
      expect(statsFor(s, 'new').headline, 'No classes yet');
      expect(statsFor(s, 'os').attended, osBefore.attended);
    });

    test('renaming keeps every record attached', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      final before = statsFor(c.read(appProvider), 'maths');

      c.read(appProvider.notifier).upsertSubject(
            subMaths.copyWith(name: 'Discrete Maths', color: 0xFFABCDEF),
          );

      final after = statsFor(c.read(appProvider), 'maths');
      expect(c.read(appProvider).subjectById('maths')!.name, 'Discrete Maths');
      expect(after.attended, before.attended);
      expect(after.held, before.held);
      expect(c.read(appProvider).subjects, hasLength(4), reason: 'no duplicate');
    });

    test('a subject with no timetable entries reports zero per week', () {
      final s = testState().copyWith(
        subjects: [...testSubjects, const Subject(id: 'x', name: 'X', color: 1)],
      );
      expect(weeklyUnits(s, 'x'), 0);
      expect(statsFor(s, 'x').hasData, isFalse);
    });

    test('changing the target changes only that subject', () {
      final c = containerWith(testState());
      c.read(appProvider.notifier).setTargetForSubject('os', 0.9);

      expect(c.read(appProvider).subjectById('os')!.targetPercent, 0.9);
      expect(c.read(appProvider).subjectById('maths')!.targetPercent, 0.75);
    });
  });

  group('timetable editing', () {
    test('deleting one entry leaves the other class of the same subject', () {
      final c = containerWith(testState());
      c.read(appProvider.notifier).deleteSlot('s1'); // Maths 9:00

      final s = c.read(appProvider);
      expect(weeklyUnits(s, 'maths'), 1);
      expect(occurrencesOn(s, monday).where((o) => o.slot.subjectId == 'maths'),
          hasLength(1));
    });

    test('deleting a slot keeps records already generated for it', () {
      final c = containerWith(catchUp(testState(), mondayNight));
      c.read(appProvider.notifier).deleteSlot('s1');

      // History is frozen: editing the timetable in week 8 must not rewrite
      // week 1.
      expect(
        c.read(appProvider).records.any((r) => r.slotId == 's1'),
        isTrue,
      );
    });

    test('copyDay clones entries with fresh ids and replaces the target', () {
      final c = containerWith(testState());
      c.read(appProvider.notifier).copyDay(DateTime.monday, DateTime.friday);

      final s = c.read(appProvider);
      final fri = s.slots.where((x) => x.weekday == DateTime.friday).toList();
      final mon = s.slots.where((x) => x.weekday == DateTime.monday).toList();

      expect(fri, hasLength(mon.length));
      expect(
        fri.map((x) => x.id).toSet().intersection(mon.map((x) => x.id).toSet()),
        isEmpty,
        reason: 'cloned entries must not share ids',
      );
      // Times and untimed-ness carry over.
      expect(fri.where((x) => !x.isTimed), hasLength(1));
    });

    test('copying onto a day wipes what was there before', () {
      final c = containerWith(testState());
      c.read(appProvider.notifier).copyDay(DateTime.tuesday, DateTime.monday);

      final mon = c
          .read(appProvider)
          .slots
          .where((x) => x.weekday == DateTime.monday);
      expect(mon, hasLength(1), reason: 'Tuesday only has one class');
    });
  });

  group('shapes the old period grid could not express', () {
    test('two classes at the exact same time both survive', () {
      final s = testState(
        slots: [
          Slot(
            id: 'a',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(9),
            endMin: at(10),
          ),
          Slot(
            id: 'b',
            subjectId: 'maths',
            weekday: DateTime.monday,
            startMin: at(9),
            endMin: at(10),
          ),
        ],
      );
      expect(occurrencesOn(s, monday), hasLength(2));

      final done = catchUp(s, mondayNight);
      expect(done.records, hasLength(2));
    });

    test('overlapping classes of different lengths both count once', () {
      final s = testState(
        slots: [
          Slot(
            id: 'long',
            subjectId: 'oslab',
            weekday: DateTime.monday,
            startMin: at(9),
            endMin: at(12),
          ),
          Slot(
            id: 'short',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(10),
            endMin: at(10, 50),
          ),
        ],
      );
      final done = catchUp(s, mondayNight);
      expect(done.records, hasLength(2));
      expect(done.records.every((r) => r.units == 1), isTrue,
          reason: 'length never affects how much a class counts');
    });

    test('a class at an odd time needs no bell schedule to exist', () {
      final s = testState(
        slots: [
          Slot(
            id: 'odd',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(7, 35),
            endMin: at(8, 05),
          ),
        ],
      );
      expect(occurrencesOn(s, monday).single.slot.timeLabel,
          '7:35 am – 8:05 am');
    });

    test('weekend classes work', () {
      final s = testState(
        slots: [
          Slot(
            id: 'sun',
            subjectId: 'os',
            weekday: DateTime.sunday,
            startMin: at(10),
          ),
        ],
      );
      final sunday = monday.add(const Duration(days: 6));
      expect(occurrencesOn(s, sunday), hasLength(1));
    });

    test('a mix of timed and untimed on one day orders and settles correctly',
        () {
      final s = testState(
        slots: [
          const Slot(id: 'u1', subjectId: 'sem', weekday: DateTime.monday),
          Slot(
            id: 't1',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(16),
            endMin: at(17),
          ),
          const Slot(id: 'u2', subjectId: 'maths', weekday: DateTime.monday),
        ],
      );

      expect(occurrencesOn(s, monday).map((o) => o.slot.id).first, 't1');

      // 17:30 — the timed 16:00 class is done, both untimed ones are not.
      final part = catchUp(s, DateTime(2026, 8, 3, 17, 30));
      expect(part.records.map((r) => r.slotId).toSet(), {'t1'});

      final all = catchUp(s, DateTime(2026, 8, 3, 18, 30));
      expect(all.records, hasLength(3));
    });
  });

  group('save file round-trips', () {
    test('everything survives encode and decode', () {
      final original = catchUp(testState(end: DateTime(2026, 12, 1)), mondayNight);
      final restored = AppState.fromJson(original.toJson());

      expect(restored.subjects.map((s) => s.id),
          original.subjects.map((s) => s.id));
      expect(restored.slots.length, original.slots.length);
      expect(restored.records.length, original.records.length);
      expect(restored.term!.endDate, original.term!.endDate);
      expect(restored.settings.dayEndsAtMinutes,
          original.settings.dayEndsAtMinutes);

      // The untimed slot must come back untimed, not as midnight.
      final untimed = restored.slotById('s4')!;
      expect(untimed.startMin, isNull);
      expect(untimed.isTimed, isFalse);
    });

    test('a save file without the day-end setting defaults to 6 pm', () {
      final json = testState().toJson();
      (json['settings'] as Map<String, dynamic>).remove('dayEndsAtMinutes');
      expect(AppState.fromJson(json).settings.dayEndsAtMinutes, 18 * 60);
    });

    test('an empty app round-trips without inventing anything', () {
      final restored = AppState.fromJson(const AppState().toJson());
      expect(restored.term, isNull);
      expect(restored.subjects, isEmpty);
      expect(restored.isConfigured, isFalse);
    });
  });

  group('history does not follow later timetable edits', () {
    // Reported from real use: a class added to Friday this week appeared on
    // every *previous* Friday too, showing a default "Present". The records
    // were untouched -- catch-up only walks forward -- so the numbers stayed
    // right while the screen showed classes that never happened.
    final laterMonday = monday.add(const Duration(days: 7));

    AppState withNewMondayClass() {
      // A full week is recorded, then a new Monday entry is added afterwards.
      var s = catchUp(testState(), mondayNight);
      return s.copyWith(
        slots: [
          ...s.slots,
          Slot(
            id: 'added-later',
            subjectId: 'os',
            weekday: DateTime.monday,
            startMin: at(16),
            endMin: at(17),
          ),
        ],
      );
    }

    test('a newly added class does not appear on past days', () {
      final s = withNewMondayClass();
      final view = dayView(s, monday, now: laterMonday);

      expect(
        view.scheduled.any((o) => o.slot.id == 'added-later'),
        isFalse,
        reason: 'it did not exist on that date',
      );
      expect(
        view.extras.any((r) => r.slotId == 'added-later'),
        isFalse,
      );
    });

    test('but it does appear today, where it can still be marked', () {
      final s = withNewMondayClass();
      final view = dayView(s, laterMonday, now: laterMonday);
      expect(view.scheduled.any((o) => o.slot.id == 'added-later'), isTrue);
    });

    test('past days still show everything that was recorded', () {
      final s = withNewMondayClass();
      final view = dayView(s, monday, now: laterMonday);
      final recorded = s.records.where((r) => dateOnly(r.date) == monday);

      expect(
        view.scheduled.length + view.extras.length,
        recorded.length,
        reason: 'every record for that day is rendered exactly once',
      );
    });

    test('a record whose slot was deleted stays visible and editable', () {
      var s = catchUp(testState(), mondayNight);
      s = s.copyWith(slots: [for (final x in s.slots) if (x.id != 's1') x]);

      final view = dayView(s, monday, now: laterMonday);
      expect(
        view.extras.any((r) => r.slotId == 's1'),
        isTrue,
        reason: 'history must not vanish when the timetable changes',
      );
    });

    test('the maths is unaffected either way', () {
      // The bug was cosmetic; this pins that it stays cosmetic.
      final before = statsFor(catchUp(testState(), mondayNight), 'os');
      final after = statsFor(withNewMondayClass(), 'os');
      expect(after.attended, before.attended);
      expect(after.held, before.held);
    });
  });
}
