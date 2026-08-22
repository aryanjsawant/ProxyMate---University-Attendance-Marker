import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/data/store.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/dates.dart';
import 'package:proxymate/logic/stats.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';

import 'helpers.dart';

/// The failures here are the ones that damage or lose real data, as opposed to
/// merely drawing something wrong.
void main() {
  final mondayNight = DateTime(2026, 8, 3, 22);
  final laterMonday = monday.add(const Duration(days: 7));

  group('markWholeDay cannot invent attendance', () {
    test('a class added after the fact is not marked on past days', () {
      var s = catchUp(testState(), mondayNight);
      s = s.copyWith(
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

      final after = markWholeDay(s, monday, Status.present, now: laterMonday);
      expect(
        after.records.any((r) => r.slotId == 'added-later'),
        isFalse,
        reason: 'it never met on that Monday',
      );
    });

    test('it still marks everything that was recorded that day', () {
      final s = catchUp(testState(), mondayNight);
      final before = s.records.where((r) => dateOnly(r.date) == monday).length;

      final after = markWholeDay(s, monday, Status.cancelled, now: laterMonday);
      final touched = after.records
          .where((r) => dateOnly(r.date) == monday)
          .where((r) => r.status == Status.cancelled)
          .length;

      expect(touched, before, reason: 'every recorded class was cancelled');
    });

    test('today still marks the full timetable, recorded or not', () {
      // Nothing has elapsed at 08:00, so nothing is recorded yet.
      final s = testState();
      final after = markWholeDay(
        s,
        monday,
        Status.absent,
        now: DateTime(2026, 8, 3, 8),
      );
      expect(after.records, hasLength(4), reason: "Monday's four classes");
    });
  });

  group('a wrong phone clock does not stop attendance for good', () {
    test('a future stamp is clamped, not treated as a dead end', () {
      // The clock was wrong when this was written.
      final s = testState().copyWith(
        lastGeneratedDate: DateTime(2027, 1, 1),
      );

      final after = catchUp(s, mondayNight);
      expect(
        after.records,
        isNotEmpty,
        reason: 'catch-up must recover once the clock is right again',
      );
      expect(after.lastGeneratedDate, dateOnly(mondayNight));
    });

    test('and the repaired stamp survives, so it self-heals once', () {
      var s = testState().copyWith(lastGeneratedDate: DateTime(2027, 1, 1));
      s = catchUp(s, mondayNight);
      final count = s.records.length;

      s = catchUp(s, mondayNight);
      expect(s.records, hasLength(count), reason: 'idempotent afterwards');
    });
  });

  group('saving cannot interleave into a corrupt file', () {
    test('rapid overlapping saves leave valid, newest-wins JSON', () async {
      final dir = await Directory.systemTemp.createTemp('proxymate-save');
      addTearDown(() => dir.delete(recursive: true));

      final store = _StoreInDir(dir);
      var s = catchUp(testState(), mondayNight);

      // Fire many saves without awaiting, as the app does on every tap.
      final futures = <Future<void>>[];
      for (var i = 0; i < 40; i++) {
        s = s.copyWith(
          subjects: [
            ...testSubjects,
            Subject(id: 'extra$i', name: 'Extra $i', color: 0xFF000000),
          ],
        );
        futures.add(store.save(s));
      }
      await Future.wait(futures);

      final raw = File('${dir.path}${Platform.pathSeparator}${Store.fileName}')
          .readAsStringSync();
      final restored =
          AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(restored.records, hasLength(s.records.length));
      expect(
        restored.subjects.any((x) => x.id == 'extra39'),
        isTrue,
        reason: 'the last save wins',
      );
    });
  });

  group('the maths is unaffected by all of the above', () {
    test('marking a past day whole does not change untouched subjects', () {
      final s = catchUp(testState(), mondayNight);
      final before = statsFor(s, 'oslab');
      final after = markWholeDay(s, monday, Status.absent, now: laterMonday);
      expect(statsFor(after, 'oslab').attended, before.attended);
      expect(statsFor(after, 'oslab').held, before.held);
    });
  });
}

/// Store writes to the app documents directory, which does not exist under
/// `flutter test`. This points it at a temp directory instead.
class _StoreInDir extends Store {
  _StoreInDir(this.dir);
  final Directory dir;

  @override
  Future<File> resolveFile() async =>
      File('${dir.path}${Platform.pathSeparator}${Store.fileName}');
}
