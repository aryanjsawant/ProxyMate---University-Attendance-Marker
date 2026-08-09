import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/defaults.dart';
import '../../logic/dates.dart';
import '../../models/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../widgets/status_toggle.dart';
import '../subject_editor.dart';
import '../timetable_editor.dart';

/// First run.
///
/// The walkthrough exists because the core idea is genuinely counterintuitive:
/// every other attendance app makes you mark yourself *present*, so a screen
/// full of preselected P buttons reads as broken until someone explains that
/// presence is the assumption. Three cheap screens buy that understanding.
///
/// Subjects and timetable are both skippable — someone installing this at the
/// back of a lecture should be able to reach a working app in 20 seconds and
/// fill in the schedule later.
class SetupWizard extends ConsumerStatefulWidget {
  const SetupWizard({super.key});

  @override
  ConsumerState<SetupWizard> createState() => _SetupWizardState();
}

class _SetupWizardState extends ConsumerState<SetupWizard> {
  final _controller = PageController();
  int _page = 0;

  DateTime _start = defaultTermStart();
  DateTime? _end;
  double _target = 0.75;

  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    final notifier = ref.read(appProvider.notifier);

    notifier.updateSettings(
      ref.read(appProvider).settings.copyWith(hasSeenWalkthrough: true),
    );
    notifier.completeSetup(
      term: Term(
        name: 'Semester',
        startDate: _start,
        endDate: _end,
        defaultTarget: _target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSkipToEnd = _page == 2 || _page == 3;

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
                  const _IdeaPage(),
                  const _MarkingPage(),
                  const _SubjectsPage(),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                  if (canSkipToEnd && _page < _pageCount - 1)
                    TextButton(
                      onPressed: () => _controller.animateToPage(
                        _pageCount - 1,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Skip for now'),
                    ),
                  const SizedBox(width: 8),
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

class _IdeaPage extends StatelessWidget {
  const _IdeaPage();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    children: [
      Text(
        'ProxyMate',
        style: context.text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'This app assumes you went.',
        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(
        'Every class on your timetable is marked present the moment it ends. '
        'You never open the app to say you attended.',
        style: TextStyle(
          color: context.colors.onSurfaceVariant,
          height: 1.55,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 24),
      _Point(
        icon: Icons.notifications_off_outlined,
        title: 'Attend everything, open nothing',
        body: 'A perfect week costs you zero taps.',
      ),
      _Point(
        icon: Icons.touch_app_outlined,
        title: 'Skipped one? One tap',
        body: 'Open the app, tap A on that class. Done.',
      ),
      _Point(
        icon: Icons.calculate_outlined,
        title: 'It does the arithmetic',
        body:
            'How many more you can miss, or how many you must attend to climb '
            'back to 75%.',
      ),
    ],
  );
}

/// The screen that earns its place: P/A/C is compact but opaque on first
/// contact, so it gets shown working rather than described.
class _MarkingPage extends StatefulWidget {
  const _MarkingPage();

  @override
  State<_MarkingPage> createState() => _MarkingPageState();
}

class _MarkingPageState extends State<_MarkingPage> {
  Status _demo = Status.present;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    children: [
      Text(
        'Marking takes one tap',
        style: context.text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Every class has these three buttons. Try them.',
        style: TextStyle(color: context.colors.onSurfaceVariant),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '9:30 am',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const Text(
                      'Operating Systems',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              StatusToggle(
                value: _demo,
                onChanged: (s) => setState(() => _demo = s),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      _Legend(
        letter: 'P',
        colour: context.risk.safe,
        title: 'Present',
        body:
            'Already selected for you. This is the default — you only change it '
            'when it is wrong.',
        active: _demo == Status.present,
      ),
      _Legend(
        letter: 'A',
        colour: context.risk.danger,
        title: 'Absent',
        body: 'You skipped it. Counts against your percentage.',
        active: _demo == Status.absent,
      ),
      _Legend(
        letter: 'C',
        colour: context.risk.unknown,
        title: 'Cancelled',
        body:
            'The class never happened. Counts against neither side — it does '
            'not dent your percentage at all.',
        active: _demo == Status.cancelled,
      ),
      const SizedBox(height: 8),
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
              'Long-press a class for extras: how many periods it counts for, '
              'a note, or the room.',
              style: TextStyle(
                fontSize: 12.5,
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

class _SubjectsPage extends ConsumerWidget {
  const _SubjectsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(appProvider).subjects;
    final slots = ref.watch(appProvider).slots.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        Text(
          'Your subjects',
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add each one you want tracked. Labs are their own subject — colleges '
          'usually enforce a separate 75% on them.',
          style: TextStyle(
            color: context.colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (subjects.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 28,
                horizontal: 20,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: context.colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No subjects yet',
                    style: TextStyle(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < subjects.length; i++) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(subjects[i].color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(subjects[i].name),
                    subtitle: subjects[i].faculty == null
                        ? null
                        : Text(subjects[i].faculty!),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => showSubjectEditor(context, subjects[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add subject'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => showSubjectEditor(context, null),
          ),
        ),
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Weekly timetable',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            slots == 0
                ? 'Not set up yet. Without it nothing is auto-marked — you can '
                      'still add it later from More.'
                : '$slots ${slots == 1 ? 'class' : 'classes'} a week',
            style: TextStyle(
              fontSize: 13,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(slots == 0 ? 'Build timetable' : 'Edit timetable'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TimetableEditor()),
              ),
            ),
          ),
        ],
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
    padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
    children: [
      Text(
        'When does the term run?',
        style: context.text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Attendance is counted from the start date. Anything before it is '
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
              subtitle: const Text('Optional — unlocks term projections'),
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
              'classes this term and how many you can miss across all of it — '
              'not just today.',
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

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Point({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: context.colors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  final String letter;
  final Color colour;
  final String title;
  final String body;
  final bool active;

  const _Legend({
    required this.letter,
    required this.colour,
    required this.title,
    required this.body,
    required this.active,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: active
          ? colour.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
