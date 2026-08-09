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
import 'package:proxymate/widgets/status_toggle.dart';

import 'helpers.dart';

/// Drives the real widgets against real state. These are the closest thing to
/// "does the app work" that runs without a phone.
void main() {
  /// Pumps a screen with the clock frozen mid-Monday-morning: periods 1 and 2
  /// have finished, period 3 has not started.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    AppState? initial,
    DateTime? now,
  }) async {
    final when = now ?? DateTime(2026, 8, 3, 10, 25);
    final state = catchUp(
      (initial ?? enrolledState()).copyWith(lastGeneratedDate: monday),
      when,
    );

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
    testWidgets('lists today\'s classes with their times', (tester) async {
      await pump(tester, const HomeScreen());

      // Monday: IR, AC, ILLM, AIFS, then the IMAES lab.
      expect(find.text('IR'), findsOneWidget);
      expect(find.text('AC'), findsOneWidget);
      expect(find.text('ILLM'), findsOneWidget);
      expect(find.text('AIFS'), findsOneWidget);
      expect(find.text('IMAES'), findsOneWidget);
      expect(find.text('8:30 am'), findsOneWidget);
    });

    testWidgets('every class row carries its own P/A/C control', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.byType(StatusToggle), findsNWidgets(5));
    });

    testWidgets('the 2-period lab is labelled as such', (tester) async {
      await pump(tester, const HomeScreen());
      expect(find.textContaining('2 periods'), findsOneWidget);
    });

    testWidgets('shows the standings section below the divider', (
      tester,
    ) async {
      await pump(tester, const HomeScreen());
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('WHERE YOU STAND'), findsOneWidget);
      expect(find.byType(Divider), findsWidgets);
    });

    testWidgets('a day with no classes says so instead of rendering empty', (
      tester,
    ) async {
      // Saturday.
      await pump(tester, const HomeScreen(), now: DateTime(2026, 8, 8, 12));
      expect(find.text('No classes today'), findsOneWidget);
    });
  });

  group('marking', () {
    testWidgets('tapping A records an absence and offers undo', (tester) async {
      final container = await pump(tester, const HomeScreen());

      final before = statsFor(container.read(appProvider), 'ai455-th');
      expect(before.attended, 1);
      expect(before.held, 1);

      // First row is 8:30 IR; tap its "A" segment.
      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();

      final after = statsFor(container.read(appProvider), 'ai455-th');
      expect(after.attended, 0);
      expect(after.held, 1);
      expect(find.text('Marked absent'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('undo puts the record back', (tester) async {
      final container = await pump(tester, const HomeScreen());

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();
      expect(statsFor(container.read(appProvider), 'ai455-th').attended, 0);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(statsFor(container.read(appProvider), 'ai455-th').attended, 1);
    });

    testWidgets('cancelling removes the class from the denominator', (
      tester,
    ) async {
      final container = await pump(tester, const HomeScreen());

      await tester.tap(find.text('C').first);
      await tester.pumpAndSettle();

      final s = statsFor(container.read(appProvider), 'ai455-th');
      expect(s.held, 0, reason: 'cancelled counts against neither side');
      expect(s.cancelled, 1);
    });

    testWidgets('a class that has not ended yet is still markable', (
      tester,
    ) async {
      // 8:00 am Monday — nothing has elapsed.
      final container = await pump(
        tester,
        const HomeScreen(),
        now: DateTime(2026, 8, 3, 8, 0),
      );
      expect(container.read(appProvider).records, isEmpty);

      await tester.tap(find.text('A').first);
      await tester.pumpAndSettle();

      final s = statsFor(container.read(appProvider), 'ai455-th');
      expect(s.held, 1);
      expect(s.attended, 0);
    });
  });

  group('Subjects', () {
    testWidgets('theory and lab appear as separate rows under one course', (
      tester,
    ) async {
      await pump(tester, const SubjectsScreen());

      expect(find.text('Affective Computing'), findsOneWidget);
      // AC has both a theory and a lab component.
      expect(find.text('Theory'), findsWidgets);
      expect(find.text('Lab'), findsWidgets);
    });

    testWidgets('each card shows one actionable line, not a pile of numbers', (
      tester,
    ) async {
      // A full elapsed week, so the numbers are meaningful rather than 1/1.
      await pump(
        tester,
        const SubjectsScreen(),
        now: DateTime(2026, 8, 7, 18),
      );
      expect(find.textContaining('You can miss'), findsWidgets);
    });

    testWidgets('a failing component reports a recovery target', (
      tester,
    ) async {
      // Hand-build a state where IR theory is well below 75%.
      var s = enrolledState();
      final records = <AttendanceRecord>[];
      var day = DateTime(2026, 7, 21);
      for (var i = 0; i < 20; i++) {
        day = DateTime(day.year, day.month, day.day + 1);
        records.add(
          AttendanceRecord(
            id: 'x$i',
            componentId: 'ai455-th',
            date: day,
            status: i < 10 ? Status.present : Status.absent,
            units: 1,
            isManual: true,
          ),
        );
      }
      s = s.copyWith(records: records, lastGeneratedDate: DateTime(2026, 8, 20));

      await pump(
        tester,
        const SubjectsScreen(),
        initial: s,
        now: DateTime(2026, 8, 20, 18),
      );

      expect(find.textContaining('Attend next'), findsWidgets);
    });
  });
}
