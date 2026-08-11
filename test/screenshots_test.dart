@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:proxymate/logic/attendance.dart';
import 'package:proxymate/models/app_state.dart';
import 'package:proxymate/models/models.dart';
import 'package:proxymate/screens/history.dart';
import 'package:proxymate/screens/home.dart';
import 'package:proxymate/screens/subject_detail.dart';
import 'package:proxymate/screens/subjects.dart';
import 'package:proxymate/screens/timetable_editor.dart';
import 'package:proxymate/state/providers.dart';
import 'package:proxymate/theme.dart';

import 'helpers.dart';

/// Renders the real screens to PNG for the README.
///
/// Run with:  flutter test --update-goldens --tags screenshots
///
/// These are screenshots, not regression goldens — they are excluded from the
/// normal run via the tag, because a deliberate UI tweak should never fail the
/// build.
Future<void> _loadFonts() async {
  // Icons come from the app bundle via FontManifest.
  final manifest = await rootBundle.loadStructuredData<Iterable<dynamic>>(
    'FontManifest.json',
    (s) async => json.decode(s) as Iterable<dynamic>,
  );
  for (final font in manifest) {
    final family = font['family'] as String;
    final loader = FontLoader(family);
    for (final asset in font['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load(asset['asset'] as String));
    }
    await loader.load();
  }

  // Text does not: Android supplies Roboto at runtime, so it is not in the
  // bundle and `flutter test` falls back to a font whose glyphs are all
  // rectangles. The Flutter SDK ships the real Roboto for its own tooling —
  // borrow it here so the screenshots show actual words. Test-only; the app
  // itself is untouched.
  final sdkFonts = _findMaterialFonts();
  final roboto = FontLoader('Roboto');
  var loaded = 0;
  for (final face in const [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    final f = File(p.join(sdkFonts.path, face));
    if (f.existsSync()) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      loaded++;
    }
  }
  // Fail loudly. Silently skipping this produces screenshots where every word
  // is a black rectangle, which is worse than no screenshots at all.
  if (loaded == 0) {
    throw StateError('No Roboto faces found in ${sdkFonts.path}');
  }
  await roboto.load();
}

/// Walks up from the test runner binary looking for the SDK's bundled fonts.
/// The runner lives somewhere under `bin/cache/artifacts/`, but exactly how
/// deep varies by platform and Flutter version, so search rather than guess.
Directory _findMaterialFonts() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null) {
    final d = Directory(
      p.join(fromEnv, 'bin', 'cache', 'artifacts', 'material_fonts'),
    );
    if (d.existsSync()) return d;
  }

  var dir = Directory(p.dirname(Platform.resolvedExecutable));
  for (var i = 0; i < 12; i++) {
    final candidate = Directory(p.join(dir.path, 'material_fonts'));
    if (candidate.existsSync()) return candidate;

    final nested = Directory(
      p.join(dir.path, 'artifacts', 'material_fonts'),
    );
    if (nested.existsSync()) return nested;

    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'Could not locate the Flutter SDK material_fonts directory from '
    '${Platform.resolvedExecutable}. Set FLUTTER_ROOT.',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  /// A realistic mid-semester state: a few weeks in, one subject in trouble.
  AppState demoState() {
    const subjects = [
      Subject(id: 'os', name: 'Operating Systems', color: 0xFF6366F1),
      Subject(id: 'dbms', name: 'Database Systems', color: 0xFF10B981),
      Subject(id: 'maths', name: 'Discrete Maths', color: 0xFFF59E0B),
      Subject(id: 'oslab', name: 'OS Lab', color: 0xFFF43F5E),
      Subject(id: 'sem', name: 'Seminar', color: 0xFF0EA5E9),
    ];

    final slots = <Slot>[
      Slot(id: 'a', subjectId: 'maths', weekday: DateTime.monday, startMin: at(9), endMin: at(9, 50)),
      Slot(id: 'b', subjectId: 'os', weekday: DateTime.monday, startMin: at(10), endMin: at(10, 50)),
      Slot(id: 'c', subjectId: 'dbms', weekday: DateTime.monday, startMin: at(11), endMin: at(11, 50)),
      Slot(id: 'd', subjectId: 'maths', weekday: DateTime.monday, startMin: at(14), endMin: at(14, 50)),
      const Slot(id: 'e', subjectId: 'sem', weekday: DateTime.monday),
      Slot(id: 'f', subjectId: 'oslab', weekday: DateTime.tuesday, startMin: at(9), endMin: at(11)),
      Slot(id: 'g', subjectId: 'os', weekday: DateTime.wednesday, startMin: at(10), endMin: at(10, 50)),
      Slot(id: 'h', subjectId: 'dbms', weekday: DateTime.thursday, startMin: at(9), endMin: at(9, 50)),
      Slot(id: 'i', subjectId: 'maths', weekday: DateTime.friday, startMin: at(11), endMin: at(11, 50)),
    ];

    // Start four weeks back so the numbers look lived-in.
    final start = DateTime(2026, 7, 6);
    var s = AppState(
      term: Term(
        name: 'Semester',
        startDate: start,
        endDate: DateTime(2026, 11, 20),
        defaultTarget: 0.75,
      ),
      subjects: subjects,
      slots: slots,
    );

    s = catchUp(s, DateTime(2026, 8, 3, 12, 30));

    // Sprinkle in a believable set of misses: OS is the one in trouble.
    var osMissed = 0;
    var mathsMissed = 0;
    final records = <AttendanceRecord>[];
    for (final r in s.records) {
      if (r.subjectId == 'os' && osMissed < 4) {
        osMissed++;
        records.add(r.copyWith(status: Status.absent, isManual: true));
      } else if (r.subjectId == 'maths' && mathsMissed < 2) {
        mathsMissed++;
        records.add(r.copyWith(status: Status.absent, isManual: true));
      } else {
        records.add(r);
      }
    }
    return s.copyWith(records: records);
  }

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget screen, {
    AppState? state,
    DateTime? now,
  }) async {
    // flutter_test defaults this to true, which paints every shadow as a hard
    // black outline — fine for diffing, wrong for a screenshot. It must be
    // restored inside the test body: debugAssertAllPaintingVarsUnset runs
    // before addTearDown callbacks, so a tear-down would be too late.
    debugDisableShadows = false;
    try {
      final when = now ?? DateTime(2026, 8, 3, 12, 30);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(1170, 2532);

      final container = ProviderContainer(
        overrides: [clockProvider.overrideWith((ref) => when)],
      );
      addTearDown(container.dispose);
      container
          .read(appProvider.notifier)
          .applyImportedTimetable(state ?? demoState());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../docs/screenshots/$name.png'),
      );
    } finally {
      debugDisableShadows = true;
    }
  }

  testWidgets('home', (t) => shoot(t, 'home', const HomeScreen()));

  testWidgets(
    'subjects',
    (t) => shoot(t, 'subjects', const SubjectsScreen()),
  );

  testWidgets(
    'subject-detail',
    (t) => shoot(t, 'subject-detail', const SubjectDetailScreen(subjectId: 'os')),
  );

  testWidgets('history', (t) => shoot(t, 'history', const HistoryScreen()));

  testWidgets(
    'timetable',
    (t) => shoot(t, 'timetable', const TimetableEditor()),
  );
}
