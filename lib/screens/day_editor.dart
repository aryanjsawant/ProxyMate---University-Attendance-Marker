import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/attendance.dart' as engine;
import '../logic/dates.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/class_row.dart';

/// The "intricate changes" surface: fix a class you forgot to mark, log an
/// anomaly, add a class the teacher held off-timetable, or wipe a whole day.
///
/// It reuses [ClassRow] so correcting three weeks ago feels exactly like
/// correcting today.
class DayEditorScreen extends ConsumerWidget {
  final DateTime date;
  const DayEditorScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final day = dateOnly(date);
    final view = engine.dayView(state, day);

    // Far-future reference time so past classes render as settled rather than
    // "upcoming" — this screen is about history, not anticipation.
    final asIfElapsed = DateTime(day.year, day.month, day.day, 23, 59);
    final now = ref.watch(clockProvider);
    final reference = day.isBefore(dateOnly(now)) ? asIfElapsed : now;

    return Scaffold(
      appBar: AppBar(
        title: Text(formatLongDate(day)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, ref, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'cancel-day',
                child: Text('Mark whole day cancelled'),
              ),
              PopupMenuItem(
                value: 'present-day',
                child: Text('Mark everything present'),
              ),
              PopupMenuItem(
                value: 'absent-day',
                child: Text('Mark everything absent'),
              ),
              PopupMenuItem(
                value: 'range',
                child: Text('Mark a date range as no-class…'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (view.scheduled.isEmpty && view.extras.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.term == null
                          ? 'No term configured'
                          : 'Nothing was scheduled on this day',
                      style: TextStyle(
                        color: context.colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < view.scheduled.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    ClassRow(
                      occurrence: view.scheduled[i],
                      record: engine.recordForOccurrence(
                        state,
                        view.scheduled[i],
                      ),
                      now: reference,
                    ),
                  ],
                  for (var i = 0; i < view.extras.length; i++) ...[
                    if (i > 0 || view.scheduled.isNotEmpty)
                      const Divider(indent: 16, endIndent: 16),
                    ExtraClassRow(record: view.extras[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add extra class'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => showAddExtraClassSheet(context, day),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Long-press any class to change how many periods it counts for, '
            'add a note, or delete it.',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final notifier = ref.read(appProvider.notifier);
    final day = dateOnly(date);

    switch (value) {
      case 'cancel-day':
        notifier.markWholeDay(day, Status.cancelled);
      case 'present-day':
        notifier.markWholeDay(day, Status.present);
      case 'absent-day':
        notifier.markWholeDay(day, Status.absent);
      case 'range':
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(day.year - 1),
          lastDate: DateTime(day.year + 2),
          initialDateRange: DateTimeRange(start: day, end: day),
          helpText: 'Days with no classes',
        );
        if (picked != null) {
          notifier.markRangeAsNoClass(picked.start, picked.end);
        }
    }
  }
}

/// Teachers hold classes that aren't on the timetable. This adds one with no
/// backing slot, so it counts identically to a scheduled class everywhere.
Future<void> showAddExtraClassSheet(BuildContext context, DateTime date) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _AddExtraClassSheet(date: date),
  );
}

class _AddExtraClassSheet extends ConsumerStatefulWidget {
  final DateTime date;
  const _AddExtraClassSheet({required this.date});

  @override
  ConsumerState<_AddExtraClassSheet> createState() =>
      _AddExtraClassSheetState();
}

class _AddExtraClassSheetState extends ConsumerState<_AddExtraClassSheet> {
  String? _componentId;
  Status _status = Status.present;
  int _units = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final components = state.subjects;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Extra class',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            formatLongDate(widget.date),
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _componentId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final c in components)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(c.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _componentId = v),
          ),
          const SizedBox(height: 16),
          SegmentedButton<Status>(
            segments: const [
              ButtonSegment(value: Status.present, label: Text('Present')),
              ButtonSegment(value: Status.absent, label: Text('Absent')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Counts as'),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _units > 1 ? () => setState(() => _units--) : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$_units',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _units < 8 ? () => setState(() => _units++) : null,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _componentId == null
                  ? null
                  : () {
                      ref
                          .read(appProvider.notifier)
                          .addExtraClass(
                            subjectId: _componentId!,
                            date: widget.date,
                            status: _status,
                            units: _units,
                          );
                      Navigator.of(context).pop();
                    },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}
