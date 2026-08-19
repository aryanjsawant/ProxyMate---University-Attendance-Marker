import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/logic/stats.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/state/providers.dart';

import 'helpers.dart';

/// The setup wizard promises: "Attendance is counted from the start date.
/// Anything before it is ignored." These pin that promise, and that moving the
/// start date earlier actually picks up the classes it now covers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith(AppState s) {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(appProvider.notifier).applyImportedTimetable(s);
    return c;
  }

  final laterMonday = monday.add(const Duration(days: 7));
  final nightOfSecondWeek = DateTime(2026, 8, 10, 22);
  // Bounds generation so a real-clock refresh cannot add to the fixture.
  final endOfFixture = DateTime(2026, 8, 10);

  test('records before the term start are not counted', () {
    // Two weeks recorded, then the user decides term really began in week two.
    var s = catchUp(testState(), nightOfSecondWeek);
    final beforeMove = statsFor(s, 'maths').held;
    expect(beforeMove, greaterThan(2), reason: 'two weeks of Maths recorded');

    s = s.copyWith(term: s.term!.copyWith(startDate: laterMonday));

    expect(
      statsFor(s, 'maths').held,
      2,
      reason: 'only the second week counts once the term starts later',
    );
  });

  test('records after the term end are not counted', () {
    var s = catchUp(testState(), nightOfSecondWeek);
    s = s.copyWith(term: s.term!.copyWith(endDate: monday));

    expect(
      statsFor(s, 'maths').held,
      2,
      reason: 'only the first Monday is inside the term',
    );
  });

  test('moving the start earlier backfills the newly covered days', () {
    // Catch-up resumes from lastGeneratedDate, so widening the term backwards
    // has to rewind that marker. updateTerm does it; catchUp deliberately does
    // not, because always replaying from the term start would resurrect records
    // the user had deleted (see the test below).
    final c = containerWith(catchUp(
        testState(start: laterMonday, end: endOfFixture),
        nightOfSecondWeek));
    final before = statsFor(c.read(appProvider), 'maths').held;

    final term = c.read(appProvider).term!;
    c.read(appProvider.notifier).updateTerm(term.copyWith(startDate: monday));

    expect(
      statsFor(c.read(appProvider), 'maths').held,
      greaterThan(before),
      reason: 'the earlier week should now be filled in',
    );
  });

  test('a deleted past record is not resurrected on the next launch', () {
    // This is what the lastGeneratedDate high-water mark buys, and why
    // catch-up does not simply replay the whole term every time.
    var s = catchUp(testState(), nightOfSecondWeek);
    final victim = s.records.firstWhere((r) => r.subjectId == 'maths');
    s = deleteRecord(s, victim.id);
    final after = statsFor(s, 'maths').held;

    s = catchUp(s, nightOfSecondWeek);
    expect(statsFor(s, 'maths').held, after, reason: 'stays deleted');
  });

  test('narrowing the term keeps the records, it only stops counting them', () {
    final c = containerWith(
        catchUp(testState(end: endOfFixture), nightOfSecondWeek));
    final kept = c
        .read(appProvider)
        .records
        .where((r) => r.date.isBefore(laterMonday))
        .map((r) => r.id)
        .toSet();
    expect(kept, isNotEmpty);

    final term = c.read(appProvider).term!;
    c.read(appProvider.notifier).updateTerm(
        term.copyWith(startDate: laterMonday));
    expect(
      c.read(appProvider).records.map((r) => r.id).toSet(),
      containsAll(kept),
      reason: 'narrowing the window by mistake must be undoable',
    );

    c.read(appProvider.notifier).updateTerm(term.copyWith(startDate: monday));
    expect(statsFor(c.read(appProvider), 'maths').held, greaterThan(2),
        reason: 'and widening it again restores the count');
  });
}
