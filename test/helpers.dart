import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';

/// Fixtures for a plausible generic timetable, exercising the shapes that
/// actually break attendance apps:
///
///  * a subject that meets **twice on one day** (Maths, Monday)
///  * a lab tracked as its **own subject**, not a child of a course
///  * a class with **no time set**, which must settle at the end of day
///  * a two-hour class, which is still **one** attendance
///
/// Monday is deliberately the busiest day so the week has an obvious shape.
const mondayStart = 1; // DateTime.monday

const subOs = Subject(id: 'os', name: 'Operating Systems', color: 0xFF6366F1);
const subMaths = Subject(id: 'maths', name: 'Mathematics', color: 0xFF10B981);
const subOsLab = Subject(
  id: 'oslab',
  name: 'Operating Systems Lab',
  color: 0xFFF59E0B,
);
const subSeminar = Subject(id: 'sem', name: 'Seminar', color: 0xFFF43F5E);

const testSubjects = [subOs, subMaths, subOsLab, subSeminar];

int at(int h, [int m = 0]) => h * 60 + m;

/// Mon: Maths 9:00, OS 10:00, Maths 14:00 (twice in a day), Seminar untimed
/// Tue: OS 9:00
/// Wed: OS Lab 9:00-11:00 (two hours, still one attendance)
final testSlots = <Slot>[
  Slot(
    id: 's1',
    subjectId: 'maths',
    weekday: DateTime.monday,
    startMin: at(9),
    endMin: at(9, 50),
  ),
  Slot(
    id: 's2',
    subjectId: 'os',
    weekday: DateTime.monday,
    startMin: at(10),
    endMin: at(10, 50),
  ),
  Slot(
    id: 's3',
    subjectId: 'maths',
    weekday: DateTime.monday,
    startMin: at(14),
    endMin: at(14, 50),
  ),
  // No time at all — settles at the configured end of day.
  const Slot(id: 's4', subjectId: 'sem', weekday: DateTime.monday),
  Slot(
    id: 's5',
    subjectId: 'os',
    weekday: DateTime.tuesday,
    startMin: at(9),
    endMin: at(9, 50),
  ),
  Slot(
    id: 's6',
    subjectId: 'oslab',
    weekday: DateTime.wednesday,
    startMin: at(9),
    endMin: at(11),
  ),
];

/// Monday 3 August 2026.
final monday = DateTime(2026, 8, 3);

AppState testState({
  DateTime? start,
  DateTime? end,
  List<Slot>? slots,
  List<Subject>? subjects,
  List<AttendanceRecord> records = const [],
  DateTime? lastGenerated,
  int dayEndsAt = 18 * 60,
}) => AppState(
  term: Term(
    name: 'Test',
    startDate: start ?? monday,
    endDate: end,
    defaultTarget: 0.75,
  ),
  subjects: subjects ?? testSubjects,
  slots: slots ?? testSlots,
  records: records,
  lastGeneratedDate: lastGenerated,
  settings: Settings(dayEndsAtMinutes: dayEndsAt),
);

/// Build stats directly from counts, for testing the formulas in isolation.
AttendanceRecord rec(
  String subjectId,
  DateTime date,
  Status status, {
  String? slotId,
  int units = 1,
  bool manual = false,
}) => AttendanceRecord(
  id: 'r-$subjectId-${date.day}-${status.name}-${slotId ?? 'x'}',
  subjectId: subjectId,
  date: date,
  slotId: slotId,
  status: status,
  units: units,
  isManual: manual,
);

/// A state carrying exactly [attended]/[held] plus [cancelled] for one subject,
/// for testing the formulas in isolation from the calendar.
AppState stateWithTally({
  required String subjectId,
  required int attended,
  required int held,
  int cancelled = 0,
}) {
  final records = <AttendanceRecord>[];
  var day = monday;

  for (var i = 0; i < held; i++) {
    records.add(
      rec(
        subjectId,
        day,
        i < attended ? Status.present : Status.absent,
        slotId: 'h$i',
      ),
    );
    day = day.add(const Duration(days: 1));
  }
  for (var i = 0; i < cancelled; i++) {
    records.add(rec(subjectId, day, Status.cancelled, slotId: 'c$i'));
    day = day.add(const Duration(days: 1));
  }

  return AppState(
    term: Term(name: 'Test', startDate: monday, defaultTarget: 0.75),
    subjects: [Subject(id: subjectId, name: subjectId, color: 0xFF6366F1)],
    records: records,
  );
}
