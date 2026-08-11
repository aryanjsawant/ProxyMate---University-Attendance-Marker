@Tags(['migration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/schedule.dart';
import 'package:proxymate/logic/stats.dart';
import 'package:proxymate/models/app_state.dart';

/// Validates a converted svnit backup by loading it through the real model —
/// the same code path the app's Import uses. Run with:
///
///   flutter test --tags migration
///
/// Excluded from the normal run because it depends on a file outside the repo.
void main() {
  // Point this at your own converted file:
  //   PROXYMATE_MIGRATION_FILE=... flutter test --tags migration
  final path =
      Platform.environment['PROXYMATE_MIGRATION_FILE'] ??
      'proxymate-general-import.json';

  test('converted backup loads and reads correctly', () {
    final f = File(path);
    if (!f.existsSync()) {
      markTestSkipped('no converted backup at $path');
      return;
    }

    final state = AppState.fromJson(
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    );

    expect(state.isConfigured, isTrue);
    expect(state.subjects, hasLength(9));
    expect(state.slots, hasLength(24));
    expect(state.records, hasLength(57));

    // Every slot and record points at a subject that exists.
    for (final s in state.slots) {
      expect(state.subjectById(s.subjectId), isNotNull, reason: s.id);
    }
    for (final r in state.records) {
      expect(state.subjectById(r.subjectId), isNotNull, reason: r.id);
    }
    expect(state.activeSlots, hasLength(24), reason: 'no orphaned slots');

    // One class is one attendance, everywhere.
    expect(
      state.records.every((r) => r.units == 1),
      isTrue,
      reason: 'no record may count double any more',
    );

    // The week matches the timetable: Mon 5, Tue 4, Wed 4, Thu 4, Fri 7.
    final perDay = <int, int>{};
    for (final s in state.activeSlots) {
      perDay[s.weekday] = (perDay[s.weekday] ?? 0) + 1;
    }
    expect(perDay[DateTime.monday], 5);
    expect(perDay[DateTime.tuesday], 4);
    expect(perDay[DateTime.wednesday], 4);
    expect(perDay[DateTime.thursday], 4);
    expect(perDay[DateTime.friday], 7);
    expect(state.activeSlots.length, 24);

    // Every subject has a name and at least one timetable entry.
    for (final s in state.subjects) {
      expect(s.name.trim(), isNotEmpty);
      expect(
        weeklyUnits(state, s.id),
        greaterThan(0),
        reason: '${s.name} is not on the timetable',
      );
    }

    // The subject that was entirely cancelled survives, with no percentage.
    final iot = state.subjects.firstWhere((s) => s.name.contains('IoT'));
    final iotStats = statsFor(state, iot.id);
    expect(iotStats.cancelled, 10);
    expect(iotStats.held, 0);
    expect(iotStats.hasData, isFalse);
    expect(iotStats.headline, 'No classes yet');

    // Spot-check the labs that were halved.
    for (final name in ['AC Lab', 'Agentic AI Lab', 'IMAES Lab']) {
      final subj = state.subjects.firstWhere((s) => s.name == name);
      final st = statsFor(state, subj.id);
      expect(st.held, lessThanOrEqualTo(3), reason: '$name held=${st.held}');
    }

    // Print a readable standing for eyeballing.
    // ignore: avoid_print
    print('\n--- imported standing ---');
    for (final s in allStats(state, now: DateTime(2026, 8, 11, 23))) {
      final subj = state.subjectById(s.subjectId)!;
      // ignore: avoid_print
      print(
        '${subj.name.padRight(16)} '
        '${s.hasData ? '${s.attended}/${s.held} ${(s.percent! * 100).round()}%' : '— cancelled ${s.cancelled}'}'
        '  ${s.headline}',
      );
    }
  });
}
