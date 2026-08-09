import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/stats.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';
import 'package:proxymate/screens/home.dart';
import 'package:proxymate/screens/subjects.dart';
import 'package:proxymate/state/providers.dart';
import 'package:proxymate/theme.dart';
import 'package:proxymate/widgets/class_row.dart';
import 'package:proxymate/widgets/status_toggle.dart';

import 'helpers.dart';

/// Drives the real widgets against real state — the closest thing to "does the
/// app work" that runs without a phone.
void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    AppState? initial,
    DateTime? now,
    bool runCatchUp = true,
  }) async {
    final when = now ?? DateTime(2026, 8, 3, 11, 30); // Monday, after OS 10:00
    var state = initial ?? testState();
    if (runCatchUp) state = catchUp(state, when);

    final container = ProviderContainer(
      overrides: [clockProvider.overrideWith((ref) => when)],
    );
    addTearDown(container.dispose);
    container.read(appProvider.notifier).applyImportedTimetable(state);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('Home', () {
    testWidgets('lists today\'s classes, including the untimed one', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());

      // Two Maths rows in Today, plus one row in the standings list below.
      expect(
        find.descendant(
          of: find.byType(ClassRow),
          matching: find.text('Mathematics'),
        ),
        findsNWidgets(2),
        reason: 'Maths meets twice on Monday',
      );
      expect(find.byType(ClassRow), findsNWidgets(4));
      expect(find.text('9:00 am'), findsOneWidget);
    });

    testWidgets('an untimed class is labelled rather than showing a time', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.text('No time set'), findsOneWidget);
    });

    testWidgets('every class row carries its own P/A/C control', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.byType(StatusToggle), findsNWidgets(4));
    });

    testWidgets('a day with no classes says so', (tester) async {
      // Thursday.
      await pump(tester, const HomeScreen(), now: DateTime(2026, 8, 6, 12));
      expect(find.text('No classes today'), findsOneWidget);
    });

    testWidgets('with no subjects at all it points at setup', (tester) async {
      await pump(
        tester,
        const HomeScreen(),
        initial: const AppState(
          term: null,
        ).copyWith(term: Term(name: 't', startDate: DateTime(2026, 8, 3))),
      );
      expect(find.textContaining('Add your subjects'), findsOneWidget);
    });

    testWidgets('with subjects but an empty timetable it says so', (
      tester,
    ) async {
      await pump(
        tester,
        const HomeScreen(),
        initial: testState(slots: const []),
      );
      expect(find.textContaining('timetable'), findsWidgets);
    });
  });

  group('marking', () {
    testWidgets('tapping A records an absence and offers undo', (tester) async {
      final c = await pump(tester, const HomeScreen());

      expect(statsFor(c.read(appProvider), 'maths').attended, 1);

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();

      expect(statsFor(c.read(appProvider), 'maths').attended, 0);
      expect(statsFor(c.read(appProvider), 'maths').held, 1);
      expect(find.text('Marked absent'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('undo puts the record back', (tester) async {
      final c = await pump(tester, const HomeScreen());

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      expect(statsFor(c.read(appProvider), 'maths').attended, 0);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(statsFor(c.read(appProvider), 'maths').attended, 1);
    });

    testWidgets('cancelling removes the class from the denominator', (
      tester,
    ) async {
      final c = await pump(tester, const HomeScreen());

      await tester.tap(find.text('C').first);
      await tester.pumpAndSettle();

      final s = statsFor(c.read(appProvider), 'maths');
      expect(s.held, 0);
      expect(s.cancelled, 1);
    });

    testWidgets('the two Maths classes are marked independently', (
      tester,
    ) async {
      final c = await pump(tester, const HomeScreen());

      // First Maths row (9:00) -> absent. The 14:00 one hasn't elapsed.
      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();

      final records = c
          .read(appProvider)
          .records
          .where((r) => r.subjectId == 'maths')
          .toList();
      expect(records, hasLength(1));
      expect(records.single.status, Status.absent);
      expect(records.single.slotId, 's1');
    });

    testWidgets('an untimed class is markable before the day ends', (
      tester,
    ) async {
      final c = await pump(tester, const HomeScreen());
      expect(
        c.read(appProvider).records.any((r) => r.slotId == 's4'),
        isFalse,
        reason: 'not auto-marked yet — the day is not over',
      );

      await tester.tap(find.text('A').last);
      await tester.pumpAndSettle();

      expect(statsFor(c.read(appProvider), 'sem').held, 1);
      expect(statsFor(c.read(appProvider), 'sem').attended, 0);
    });
  });

  group('Subjects', () {
    testWidgets('every subject gets its own card', (tester) async {
      await pump(tester, const SubjectsScreen());
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Operating Systems Lab'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('a lab is a plain subject, not nested under a course', (
      tester,
    ) async {
      await pump(tester, const SubjectsScreen());
      expect(find.text('Theory'), findsNothing);
      expect(find.text('Lab'), findsNothing);
    });

    testWidgets('a subject not on the timetable says so', (tester) async {
      await pump(
        tester,
        const SubjectsScreen(),
        initial: testState(slots: const []),
      );
      expect(find.text('not on timetable'), findsWidgets);
    });

    testWidgets('with no subjects it invites you to add one', (tester) async {
      await pump(
        tester,
        const SubjectsScreen(),
        initial: testState(subjects: const [], slots: const []),
      );
      expect(find.text('No subjects yet'), findsOneWidget);
      expect(find.text('Add your first subject'), findsOneWidget);
    });
  });
}
