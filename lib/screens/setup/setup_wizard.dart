import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/seed_tt.dart';
import '../../logic/dates.dart';
import '../../models/app_state.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';

/// First run.
///
/// Because the printed timetable is the *class's* rather than any one
/// student's, setup is not data entry — it is a handful of choices over an
/// already-loaded timetable: which elective you took in each shared slot, which
/// lab batch you're in, and when the term runs. About five taps.
class SetupWizard extends ConsumerStatefulWidget {
  const SetupWizard({super.key});

  @override
  ConsumerState<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<SetupWizard> {
  final _controller = PageController();
  int _page = 0;

  late AppState _base = seedClassTimetable();
  final Set<String> _chosen = {};
  String? _batch;
  bool _honours = false;

  DateTime _start = _defaultTermStart();
  DateTime? _end;
  double _target = 0.75;

  static DateTime _defaultTermStart() {
    final now = DateTime.now();
    // Odd semester starts around July, even around January.
    return now.month >= 7 ? DateTime(now.year, 7, 1) : DateTime(now.year, 1, 1);
  }

  @override
  void initState() {
    super.initState();

    // Preselect the seed's own registration so the wizard opens already valid
    // and the user only changes what's wrong. Falls back to the first of each
    // pair for any group the defaults don't cover.
    _chosen.addAll(
      seedDefaultEnrolledCourseIds.where(
        (id) => _base.courses.any((c) => c.id == id),
      ),
    );
    for (final group in _base.electiveGroups.values) {
      if (group.isEmpty) continue;
      if (group.any((c) => _chosen.contains(c.id))) continue;
      _chosen.add(group.first.id);
    }
    for (final c in _base.courses) {
      if (c.electiveGroup == null && c.slotLabel != 'H') _chosen.add(c.id);
    }

    _honours = _chosen.any(
      (id) => _base.courses.any((c) => c.id == id && c.slotLabel == 'H'),
    );
    _chosen.removeWhere(
      (id) => _base.courses.any((c) => c.id == id && c.slotLabel == 'H'),
    );

    _batch = _base.availableBatches.isEmpty
        ? null
        : _base.availableBatches.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _pageCount => 3;

  void _next() {
    if (_page < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    final enrolled = {..._chosen, if (_honours) 'ai411'};

    ref
        .read(appProvider.notifier)
        .completeSetup(
          base: _base.copyWith(
            components: [
              for (final c in _base.components) c.copyWith(targetPercent: _target),
            ],
          ),
          term: Term(
            name: 'Semester',
            startDate: _start,
            endDate: _end,
            defaultTarget: _target,
          ),
          enrolledCourseIds: enrolled,
          selectedBatch: _batch,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? context.colors.primary
                              : context.colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(
                    onUseClassTimetable: () => setState(() {
                      _base = seedClassTimetable();
                    }),
                  ),
                  _ElectivesPage(
                    base: _base,
                    chosen: _chosen,
                    batch: _batch,
                    honours: _honours,
                    onToggleCourse: (groupId, courseId) => setState(() {
                      for (final c in _base.electiveGroups[groupId] ?? const []) {
                        _chosen.remove(c.id);
                      }
                      _chosen.add(courseId);
                    }),
                    onBatch: (b) => setState(() => _batch = b),
                    onHonours: (v) => setState(() => _honours = v),
                  ),
                  _TermPage(
                    start: _start,
                    end: _end,
                    target: _target,
                    onStart: (d) => setState(() => _start = d),
                    onEnd: (d) => setState(() => _end = d),
                    onTarget: (t) => setState(() => _target = t),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                      _page == _pageCount - 1 ? 'Start tracking' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onUseClassTimetable;
  const _WelcomePage({required this.onUseClassTimetable});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
    children: [
      Text(
        'ProxyMate',
        style: context.text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'This app assumes you went.',
        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        'Every scheduled class is marked present the moment it ends. You only '
        'open the app when you skipped one — so attendance keeps itself.',
        style: TextStyle(color: context.colors.onSurfaceVariant, height: 1.5),
      ),
      const SizedBox(height: 28),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.table_chart_outlined, color: context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'B.Tech AI timetable loaded',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Periods, lectures, tutorials and labs are already in — '
                'including the Thursday lab blocks and the twice-a-day honours '
                'sessions. Next you just pick which electives you took.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'You can edit any of it later, and add classes your teachers hold '
        'off-timetable.',
        style: TextStyle(
          fontSize: 12,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _ElectivesPage extends StatelessWidget {
  final AppState base;
  final Set<String> chosen;
  final String? batch;
  final bool honours;
  final void Function(String groupId, String courseId) onToggleCourse;
  final ValueChanged<String?> onBatch;
  final ValueChanged<bool> onHonours;

  const _ElectivesPage({
    required this.base,
    required this.chosen,
    required this.batch,
    required this.honours,
    required this.onToggleCourse,
    required this.onBatch,
    required this.onHonours,
  });

  @override
  Widget build(BuildContext context) {
    final groups = base.electiveGroups;
    final groupIds = groups.keys.toList()..sort();
    final batches = base.availableBatches;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Text(
          'Which ones did you take?',
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Each slot below is shared by two courses — pick the one you are '
          'registered for.',
          style: TextStyle(color: context.colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        for (final gid in groupIds) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'SLOT $gid',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: RadioGroup<String>(
              groupValue: groups[gid]!
                  .firstWhere(
                    (c) => chosen.contains(c.id),
                    orElse: () => groups[gid]!.first,
                  )
                  .id,
              onChanged: (v) => onToggleCourse(gid, v!),
              child: Column(
                children: [
                  for (var i = 0; i < groups[gid]!.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    RadioListTile<String>(
                      value: groups[gid]![i].id,
                      title: Text(
                        groups[gid]![i].shortName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${groups[gid]![i].code} · ${groups[gid]![i].name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (batches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'LAB BATCH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: RadioGroup<String>(
              groupValue: batch,
              onChanged: onBatch,
              child: Column(
                children: [
                  for (var i = 0; i < batches.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    RadioListTile<String>(
                      value: batches[i],
                      title: Text(batches[i]),
                      subtitle: Text(
                        i == 0 ? 'Monday 2:00 – 3:50' : 'Monday 4:00 – 5:50',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Card(
          child: SwitchListTile(
            value: honours,
            onChanged: onHonours,
            title: const Text(
              'Honours course',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('AI411 Advanced Topics in Deep Learning'),
          ),
        ),
      ],
    );
  }
}

class _TermPage extends StatelessWidget {
  final DateTime start;
  final DateTime? end;
  final double target;
  final ValueChanged<DateTime> onStart;
  final ValueChanged<DateTime> onEnd;
  final ValueChanged<double> onTarget;

  const _TermPage({
    required this.start,
    required this.end,
    required this.target,
    required this.onStart,
    required this.onEnd,
    required this.onTarget,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
    children: [
      Text(
        'When does the semester run?',
        style: context.text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Attendance is counted from the start date. Classes before it are '
        'ignored.',
        style: TextStyle(color: context.colors.onSurfaceVariant),
      ),
      const SizedBox(height: 20),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('Starts'),
              trailing: Text(
                formatShortDate(start),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: start,
                  firstDate: DateTime(start.year - 2),
                  lastDate: DateTime(start.year + 2),
                );
                if (picked != null) onStart(picked);
              },
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Ends'),
              subtitle: const Text('Optional — unlocks semester projections'),
              trailing: Text(
                end == null ? 'Not set' : formatShortDate(end!),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: end ?? DateTime(start.year, start.month + 4),
                  firstDate: start,
                  lastDate: DateTime(start.year + 2),
                );
                if (picked != null) onEnd(picked);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Attendance target',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${(target * 100).round()}%',
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
              Slider(
                value: target,
                min: 0.5,
                max: 0.95,
                divisions: 9,
                label: '${(target * 100).round()}%',
                onChanged: onTarget,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 16,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Setting an end date lets the app tell you the total number of '
              'classes this semester and how many you can miss across all of '
              'it — not just today.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
