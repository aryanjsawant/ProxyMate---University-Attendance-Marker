import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../logic/dates.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'day_editor.dart';

/// Month grid with a dot per class. Days containing an absence are visually
/// obvious, and a list-mode toggle filters to *only days you missed something*
/// — which is what actually gets scanned.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  bool _listMode = false;

  @override
  Widget build(BuildContext context, ) {
    final state = ref.watch(appProvider);

    final byDay = <DateTime, List<AttendanceRecord>>{};
    for (final r in state.records) {
      (byDay[dateOnly(r.date)] ??= []).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: _listMode ? 'Show calendar' : 'Show only missed days',
            icon: Icon(_listMode ? Icons.calendar_month : Icons.filter_alt),
            onPressed: () => setState(() => _listMode = !_listMode),
          ),
        ],
      ),
      body: !state.hasSubjects
          ? _NothingYet(
              icon: Icons.menu_book_outlined,
              title: 'Nothing to show yet',
              body: 'Add subjects and a timetable, and your attendance history '
                  'will build itself here.',
            )
          : _listMode
          ? _MissedList(byDay: byDay)
          : _CalendarView(
              byDay: byDay,
              focused: _focused,
              selected: _selected,
              onFocusChanged: (d) => setState(() => _focused = d),
              onSelected: (d) {
                setState(() => _selected = d);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DayEditorScreen(date: d)),
                );
              },
            ),
    );
  }
}

/// The calendar renders a month grid whatever happens, so with no data it used
/// to look broken rather than empty. This replaces it outright.
class _NothingYet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _NothingYet({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: context.colors.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CalendarView extends StatelessWidget {
  final Map<DateTime, List<AttendanceRecord>> byDay;
  final DateTime focused;
  final DateTime? selected;
  final ValueChanged<DateTime> onFocusChanged;
  final ValueChanged<DateTime> onSelected;

  const _CalendarView({
    required this.byDay,
    required this.focused,
    required this.selected,
    required this.onFocusChanged,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TableCalendar<AttendanceRecord>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2100),
              focusedDay: focused,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
              eventLoader: (day) => byDay[dateOnly(day)] ?? const [],
              selectedDayPredicate: (day) =>
                  selected != null && dateOnly(day) == dateOnly(selected!),
              onDaySelected: (day, _) => onSelected(dateOnly(day)),
              onPageChanged: onFocusChanged,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                todayDecoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, records) {
                  if (records.isEmpty) return null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final r in records.take(4))
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: statusColor(context, r.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _Legend(),
        const SizedBox(height: 12),
        Text(
          'Tap any day to edit it — including days you were away and days the '
          'teacher went off-timetable.',
          style: TextStyle(
            fontSize: 12,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (final (status, label) in const [
        (Status.present, 'Present'),
        (Status.absent, 'Absent'),
        (Status.cancelled, 'Cancelled'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor(context, status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Only the days something went wrong — the view you actually want when
/// reconciling against the department's register.
class _MissedList extends ConsumerWidget {
  final Map<DateTime, List<AttendanceRecord>> byDay;
  const _MissedList({required this.byDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);

    final days =
        byDay.entries
            .where((e) => e.value.any((r) => r.status != Status.present))
            .toList()
          ..sort((a, b) => b.key.compareTo(a.key));

    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 36,
                color: context.risk.safe,
              ),
              const SizedBox(height: 12),
              Text(
                'Nothing missed yet',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Days you skip will show up here.',
                style: TextStyle(color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final entry = days[i];
        final bad = entry.value
            .where((r) => r.status != Status.present)
            .toList();

        return Card(
          child: ListTile(
            title: Text(formatShortDate(entry.key)),
            subtitle: Text(
              bad
                  .map((r) {
                    final course = state.subjectById(r.subjectId);
                    return '${course?.shortName ?? '?'} '
                        '(${r.status.label.toLowerCase()})';
                  })
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DayEditorScreen(date: entry.key),
              ),
            ),
          ),
        );
      },
    );
  }
}
