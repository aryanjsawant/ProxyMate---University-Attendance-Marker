import 'package:proxymate/data/seed_tt.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';

/// Monday of the reference week used across the tests. 3 Aug 2026 really is a
/// Monday — `weekIsSane` asserts it so a typo here can't silently invalidate
/// every other expectation.
final monday = DateTime(2026, 8, 3);
final tuesday = DateTime(2026, 8, 4);
final wednesday = DateTime(2026, 8, 5);
final thursday = DateTime(2026, 8, 6);
final friday = DateTime(2026, 8, 7);

final termStart = DateTime(2026, 7, 20);
final termEnd = DateTime(2026, 11, 20);

/// The default student: IMAES + Affective Computing + Information Retrieval +
/// AI for Sustainability + Intro to LLMs, Batch-I, no honours.
const defaultElectives = {'ai401', 'ai451', 'ai455', 'ai459', 'ai463'};

AppState enrolledState({
  Set<String> courseIds = defaultElectives,
  bool honours = false,
  String batch = 'Batch-I',
  DateTime? endDate,
}) {
  return seedClassTimetable().copyWith(
    term: Term(
      name: 'Autumn 2026',
      startDate: termStart,
      endDate: endDate ?? termEnd,
    ),
    enrolledCourseIds: honours ? {...courseIds, 'ai411'} : courseIds,
    selectedBatch: batch,
  );
}

/// A state carrying exactly [attended] present units and [held] - [attended]
/// absent units for one component, for exercising the arithmetic directly.
AppState stateWithTally({
  required String componentId,
  required int attended,
  required int held,
  int cancelled = 0,
  DateTime? endDate,
}) {
  final records = <AttendanceRecord>[];
  var day = DateTime(2026, 7, 20);

  AttendanceRecord mk(Status s) {
    day = DateTime(day.year, day.month, day.day + 1);
    return AttendanceRecord(
      id: 'r${records.length}',
      componentId: componentId,
      date: day,
      slotId: null,
      status: s,
      units: 1,
      isManual: true,
    );
  }

  for (var i = 0; i < attended; i++) {
    records.add(mk(Status.present));
  }
  for (var i = 0; i < held - attended; i++) {
    records.add(mk(Status.absent));
  }
  for (var i = 0; i < cancelled; i++) {
    records.add(mk(Status.cancelled));
  }

  return AppState(
    term: Term(name: 't', startDate: termStart, endDate: endDate),
    periods: seedPeriods,
    courses: seedCourses,
    components: seedComponents,
    slots: const [],
    records: records,
    enrolledCourseIds: defaultElectives,
    selectedBatch: 'Batch-I',
  );
}
