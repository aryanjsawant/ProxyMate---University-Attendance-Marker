/// The B.Tech AI class timetable, transcribed from the printed sheet.
///
/// This is the *class* timetable, not any one student's: slots B, C, D and E
/// each carry an elective pair (`AI455/AI457`) and the student takes exactly
/// one of them. Setup resolves it to a personal timetable by picking one course
/// per elective group plus a lab batch — about five taps instead of thirty
/// forms.
///
/// Sanity check encoded in the tests: a student taking AI401 + one each of
/// B/C/D/E sits through 23 periods a week (Mon 6, Tue 4, Wed 4, Thu 4,
/// Fri 5), and 27 with the honours AI411. Those are *periods*; the
/// attendance count is lower, because each two-period lab is one class.
library;

import '../models/app_state.dart';
import '../models/models.dart';

// Period boundaries, 50 minutes each, lunch 12:20-2:00.
const _p1 = 8 * 60 + 30; // 8:30
const _p2 = 9 * 60 + 30; // 9:30
const _p3 = 10 * 60 + 30; // 10:30
const _p4 = 11 * 60 + 30; // 11:30
const _p5 = 14 * 60; // 2:00
const _p6 = 15 * 60; // 3:00
const _p7 = 16 * 60; // 4:00
const _p8 = 17 * 60; // 5:00

const seedPeriods = <Period>[
  Period(index: 1, startMin: _p1, endMin: _p1 + 50),
  Period(index: 2, startMin: _p2, endMin: _p2 + 50),
  Period(index: 3, startMin: _p3, endMin: _p3 + 50),
  Period(index: 4, startMin: _p4, endMin: _p4 + 50),
  Period(index: 5, startMin: _p5, endMin: _p5 + 50),
  Period(index: 6, startMin: _p6, endMin: _p6 + 50),
  Period(index: 7, startMin: _p7, endMin: _p7 + 50),
  Period(index: 8, startMin: _p8, endMin: _p8 + 50),
];

// A calm, well-separated palette; one hue per course.
const _cIndigo = 0xFF6366F1;
const _cRose = 0xFFF43F5E;
const _cAmber = 0xFFF59E0B;
const _cEmerald = 0xFF10B981;
const _cSky = 0xFF0EA5E9;
const _cViolet = 0xFF8B5CF6;
const _cOrange = 0xFFF97316;
const _cTeal = 0xFF14B8A6;
const _cPink = 0xFFEC4899;
const _cSlate = 0xFF64748B;

const seedCourses = <Course>[
  // Slot A — common to everyone.
  Course(
    id: 'ai401',
    name: 'Intelligent Multiagent and Expert Systems',
    shortName: 'IMAES',
    code: 'AI401',
    color: _cIndigo,
    slotLabel: 'A',
    faculty: 'TA7 Arunima Sen Gupta',
    venue: 'DoAI001',
  ),

  // Slot B — pick one.
  Course(
    id: 'ai451',
    name: 'Affective Computing',
    shortName: 'AC',
    code: 'AI451',
    color: _cRose,
    slotLabel: 'B',
    electiveGroup: 'B',
    faculty: 'Dr. Sudhakar Mishra',
    venue: 'DoAI001',
  ),
  Course(
    id: 'ai453',
    name: 'Probabilistic Graphical Models',
    shortName: 'PGM',
    code: 'AI453',
    color: _cAmber,
    slotLabel: 'B',
    electiveGroup: 'B',
    faculty: 'TA Maharshi Ray',
    venue: 'DoAI101',
  ),

  // Slot C — pick one.
  Course(
    id: 'ai455',
    name: 'Information Retrieval',
    shortName: 'IR',
    code: 'AI455',
    color: _cEmerald,
    slotLabel: 'C',
    electiveGroup: 'C',
    faculty: 'Dr Rahul Dixit, TA Maharshi Ray',
    venue: 'LT 2',
  ),
  Course(
    id: 'ai457',
    name: 'Internet of Things and Edge Computing',
    shortName: 'IoT & EC',
    code: 'AI457',
    color: _cSky,
    slotLabel: 'C',
    electiveGroup: 'C',
    faculty: 'TA5 Riddhi Desai',
    venue: 'DoAI101',
  ),

  // Slot D — pick one.
  Course(
    id: 'ai459',
    name: 'AI for Sustainability',
    shortName: 'AIFS',
    code: 'AI459',
    color: _cViolet,
    slotLabel: 'D',
    electiveGroup: 'D',
    faculty: 'Dr. Nitesh Funde, TA Krupa Rajani',
    venue: 'DoAI001',
  ),
  Course(
    id: 'ai461',
    name: 'Advanced Biometric Systems and Security',
    shortName: 'ABSS',
    code: 'AI461',
    color: _cOrange,
    slotLabel: 'D',
    electiveGroup: 'D',
    faculty: 'Dr. Praveen Kumar Chandaliya, TA Priyanka Bhatt',
    venue: 'DoAI101',
  ),

  // Slot E — pick one.
  Course(
    id: 'ai463',
    name: 'Introduction to Large Language Models',
    shortName: 'ILLM',
    code: 'AI463',
    color: _cTeal,
    slotLabel: 'E',
    electiveGroup: 'E',
    faculty: 'Dr. Pruthwik Mishra',
    venue: 'DoAI001',
  ),
  Course(
    id: 'ai465',
    name: 'Agentic AI',
    shortName: 'Agentic AI',
    code: 'AI465',
    color: _cPink,
    slotLabel: 'E',
    electiveGroup: 'E',
    faculty: 'TA7 Arunima Sen Gupta',
    venue: 'DoAI101',
  ),

  // Slot H — optional honours course.
  Course(
    id: 'ai411',
    name: '(Honours) Advanced Topics in Deep Learning',
    shortName: 'Adv. DL',
    code: 'AI411',
    color: _cSlate,
    slotLabel: 'H',
    faculty: 'TA12 Krupa Rajani',
    venue: 'DoAI109',
  ),
];

/// Tutorials fold into `theory`; only the practical line gets its own
/// component, because that is the split the university actually enforces.
const seedComponents = <Component>[
  Component(id: 'ai401-th', courseId: 'ai401', kind: ComponentKind.theory),
  Component(id: 'ai401-lab', courseId: 'ai401', kind: ComponentKind.lab),
  Component(id: 'ai451-th', courseId: 'ai451', kind: ComponentKind.theory),
  Component(id: 'ai451-lab', courseId: 'ai451', kind: ComponentKind.lab),
  Component(id: 'ai453-th', courseId: 'ai453', kind: ComponentKind.theory),
  Component(id: 'ai453-lab', courseId: 'ai453', kind: ComponentKind.lab),
  Component(id: 'ai455-th', courseId: 'ai455', kind: ComponentKind.theory),
  Component(id: 'ai457-th', courseId: 'ai457', kind: ComponentKind.theory),
  Component(id: 'ai459-th', courseId: 'ai459', kind: ComponentKind.theory),
  Component(id: 'ai461-th', courseId: 'ai461', kind: ComponentKind.theory),
  Component(id: 'ai463-th', courseId: 'ai463', kind: ComponentKind.theory),
  Component(id: 'ai463-lab', courseId: 'ai463', kind: ComponentKind.lab),
  Component(id: 'ai465-th', courseId: 'ai465', kind: ComponentKind.theory),
  Component(id: 'ai465-lab', courseId: 'ai465', kind: ComponentKind.lab),
  Component(id: 'ai411-th', courseId: 'ai411', kind: ComponentKind.theory),
];

const _mon = DateTime.monday;
const _tue = DateTime.tuesday;
const _wed = DateTime.wednesday;
const _thu = DateTime.thursday;
const _fri = DateTime.friday;

/// Both sides of every elective pair are present; enrollment filters them.
///
/// Note the tutorial polarity in slot D: Monday is a lecture for AI459 but a
/// tutorial for AI461, and Tuesday is the reverse. Each still lands on 3L + 1T,
/// matching their 3-1-0 credit line.
const seedSlots = <Slot>[
  // ---------------- MONDAY ----------------
  // P1 — slot C
  Slot(id: 'm1-455', componentId: 'ai455-th', weekday: _mon, periodIndex: 1),
  Slot(id: 'm1-457', componentId: 'ai457-th', weekday: _mon, periodIndex: 1),
  // P2 — slot B
  Slot(id: 'm2-451', componentId: 'ai451-th', weekday: _mon, periodIndex: 2),
  Slot(id: 'm2-453', componentId: 'ai453-th', weekday: _mon, periodIndex: 2),
  // P3 — slot E
  Slot(id: 'm3-463', componentId: 'ai463-th', weekday: _mon, periodIndex: 3),
  Slot(id: 'm3-465', componentId: 'ai465-th', weekday: _mon, periodIndex: 3),
  // P4 — slot D, tutorial for AI461 only
  Slot(id: 'm4-459', componentId: 'ai459-th', weekday: _mon, periodIndex: 4),
  Slot(
    id: 'm4-461',
    componentId: 'ai461-th',
    weekday: _mon,
    periodIndex: 4,
    isTutorial: true,
  ),
  // P5-P6 — lab slot P11, IMAES Batch-I
  Slot(
    id: 'm5-401lab-b1',
    componentId: 'ai401-lab',
    weekday: _mon,
    periodIndex: 5,
    spanPeriods: 2,
    units: 1, // two hours long, but one attendance
    batch: 'Batch-I',
    room: 'Computing Lab-02, Ground Floor, DoAI',
  ),
  // P7-P8 — lab slot P12, IMAES Batch-II
  Slot(
    id: 'm7-401lab-b2',
    componentId: 'ai401-lab',
    weekday: _mon,
    periodIndex: 7,
    spanPeriods: 2,
    units: 1, // two hours long, but one attendance
    batch: 'Batch-II',
    room: 'Computing Lab-02, Ground Floor, DoAI',
  ),

  // ---------------- TUESDAY ----------------
  // P1 — slot D, tutorial for AI459 only
  Slot(
    id: 't1-459',
    componentId: 'ai459-th',
    weekday: _tue,
    periodIndex: 1,
    isTutorial: true,
  ),
  Slot(id: 't1-461', componentId: 'ai461-th', weekday: _tue, periodIndex: 1),
  // P2 — slot C
  Slot(id: 't2-455', componentId: 'ai455-th', weekday: _tue, periodIndex: 2),
  Slot(id: 't2-457', componentId: 'ai457-th', weekday: _tue, periodIndex: 2),
  // P3 — slot A
  Slot(id: 't3-401', componentId: 'ai401-th', weekday: _tue, periodIndex: 3),
  // P4 — slot E
  Slot(id: 't4-463', componentId: 'ai463-th', weekday: _tue, periodIndex: 4),
  Slot(id: 't4-465', componentId: 'ai465-th', weekday: _tue, periodIndex: 4),

  // ---------------- WEDNESDAY ----------------
  // P1 — slot B
  Slot(id: 'w1-451', componentId: 'ai451-th', weekday: _wed, periodIndex: 1),
  Slot(id: 'w1-453', componentId: 'ai453-th', weekday: _wed, periodIndex: 1),
  // P2 — slot D
  Slot(id: 'w2-459', componentId: 'ai459-th', weekday: _wed, periodIndex: 2),
  Slot(id: 'w2-461', componentId: 'ai461-th', weekday: _wed, periodIndex: 2),
  // P3 — slot C
  Slot(id: 'w3-455', componentId: 'ai455-th', weekday: _wed, periodIndex: 3),
  Slot(id: 'w3-457', componentId: 'ai457-th', weekday: _wed, periodIndex: 3),
  // P4 — slot A
  Slot(id: 'w4-401', componentId: 'ai401-th', weekday: _wed, periodIndex: 4),

  // ---------------- THURSDAY ----------------
  // P1-P2 — lab slot P7
  Slot(
    id: 'h1-451lab',
    componentId: 'ai451-lab',
    weekday: _thu,
    periodIndex: 1,
    spanPeriods: 2,
    units: 1, // two hours long, but one attendance
    room: 'M.Tech Project Lab 1, 4th Floor CS Dept',
  ),
  Slot(
    id: 'h1-453lab',
    componentId: 'ai453-lab',
    weekday: _thu,
    periodIndex: 1,
    spanPeriods: 2,
    units: 1, // two hours long, but one attendance
    room: 'M.Tech Project Lab 2, 4th Floor CS Dept',
  ),
  // P3-P4 — lab slot P8
  Slot(
    id: 'h3-463lab',
    componentId: 'ai463-lab',
    weekday: _thu,
    periodIndex: 3,
    spanPeriods: 2,
    units: 1, // two hours long, but one attendance
    room: 'M.Tech Project Lab 1, 4th Floor CS Dept',
  ),
  Slot(
    id: 'h3-465lab',
    componentId: 'ai465-lab',
    weekday: _thu,
    periodIndex: 3,
    spanPeriods: 2,
    units: 1, // two hours long, but one attendance
    room: 'M.Tech Project Lab 2, 4th Floor CS Dept',
  ),
  // P7, P8 — slot H twice in one day, the exact case other apps can't express
  Slot(id: 'h7-411', componentId: 'ai411-th', weekday: _thu, periodIndex: 7),
  Slot(id: 'h8-411', componentId: 'ai411-th', weekday: _thu, periodIndex: 8),

  // ---------------- FRIDAY ----------------
  // P2 — slot C, tutorial for both
  Slot(
    id: 'f2-455',
    componentId: 'ai455-th',
    weekday: _fri,
    periodIndex: 2,
    isTutorial: true,
  ),
  Slot(
    id: 'f2-457',
    componentId: 'ai457-th',
    weekday: _fri,
    periodIndex: 2,
    isTutorial: true,
  ),
  // P3 — slot E
  Slot(id: 'f3-463', componentId: 'ai463-th', weekday: _fri, periodIndex: 3),
  Slot(id: 'f3-465', componentId: 'ai465-th', weekday: _fri, periodIndex: 3),
  // P4 — slot A
  Slot(id: 'f4-401', componentId: 'ai401-th', weekday: _fri, periodIndex: 4),
  // P5 — slot B
  Slot(id: 'f5-451', componentId: 'ai451-th', weekday: _fri, periodIndex: 5),
  Slot(id: 'f5-453', componentId: 'ai453-th', weekday: _fri, periodIndex: 5),
  // P6 — slot D
  Slot(id: 'f6-459', componentId: 'ai459-th', weekday: _fri, periodIndex: 6),
  Slot(id: 'f6-461', componentId: 'ai461-th', weekday: _fri, periodIndex: 6),
  // P7, P8 — slot H, second one a tutorial
  Slot(id: 'f7-411', componentId: 'ai411-th', weekday: _fri, periodIndex: 7),
  Slot(
    id: 'f8-411',
    componentId: 'ai411-th',
    weekday: _fri,
    periodIndex: 8,
    isTutorial: true,
  ),
];

/// A blank state preloaded with the class timetable. Nothing is enrolled yet —
/// the setup wizard picks one course per elective group and a lab batch.
/// The owner's actual registration, used to preselect the wizard so setup is
/// zero taps rather than five. Anyone else importing this timetable just picks
/// their own side of each pair.
///
/// One from each elective group, plus the common AI401 and the honours AI411 —
/// 27 periods a week.
const seedDefaultEnrolledCourseIds = <String>{
  'ai401', // IMAES            (slot A, common)
  'ai451', // Affective Computing        (slot B, over PGM)
  'ai457', // IoT & Edge Computing       (slot C, over IR)
  'ai459', // AI for Sustainability      (slot D, over ABSS)
  'ai465', // Agentic AI                 (slot E, over ILLM)
  'ai411', // Honours: Advanced Topics in Deep Learning (slot H)
};

AppState seedClassTimetable() => const AppState(
  periods: seedPeriods,
  courses: seedCourses,
  components: seedComponents,
  slots: seedSlots,
);
