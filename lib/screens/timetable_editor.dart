import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/notifications.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';

/// One day at a time, periods as rows, tap a cell to assign a class.
///
/// Teachers change the schedule mid-semester, so this has to be genuinely
/// usable rather than a setup-only screen. "Copy day" carries the weight when
/// entering a timetable from scratch.
class TimetableEditor extends ConsumerStatefulWidget {
  const TimetableEditor({super.key});

  @override
  ConsumerState<TimetableEditor> createState() => _TimetableEditorState();
}

class _TimetableEditorState extends ConsumerState<TimetableEditor> {
  int _weekday = DateTime.now().weekday.clamp(
    DateTime.monday,
    DateTime.friday,
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final periods = [...state.periods]..sort((a, b) => a.index.compareTo(b.index));

    final daySlots = state.slots
        .where((s) => s.weekday == _weekday && state.isSlotActive(s))
        .toList();

    // periodIndex -> the slot that starts there, plus which are covered by a
    // multi-period lab so they render as continuations rather than empty.
    final startingAt = <int, Slot>{};
    final coveredBy = <int, Slot>{};
    for (final s in daySlots) {
      startingAt[s.periodIndex] = s;
      for (var i = 1; i < s.spanPeriods; i++) {
        coveredBy[s.periodIndex + i] = s;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly timetable'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: 'Copy this day to…',
            onSelected: (v) async {
              ref
                  .read(appProvider.notifier)
                  .copyDay(_weekday, int.parse(v));
              await Notifications.instance.reschedule(ref.read(appProvider));
            },
            itemBuilder: (_) => [
              for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                if (d != _weekday)
                  PopupMenuItem(
                    value: '$d',
                    child: Text('Copy to ${weekdayName(d)}'),
                  ),
            ],
          ),
          IconButton(
            tooltip: 'Period times',
            icon: const Icon(Icons.schedule),
            onPressed: () => _editPeriods(context),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(weekdayShort(d)),
                      selected: _weekday == d,
                      onSelected: (_) => setState(() => _weekday = d),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: periods.isEmpty
                ? Center(
                    child: TextButton(
                      onPressed: () => _editPeriods(context),
                      child: const Text('Set your period times first'),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      for (final p in periods)
                        _PeriodRow(
                          period: p,
                          slot: startingAt[p.index],
                          continuationOf: coveredBy[p.index],
                          onTap: () => _assign(context, p, startingAt[p.index]),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'A lab that runs two periods is added once, on the '
                        'period it starts, with a span of 2.',
                        style: TextStyle(
                          fontSize: 12,
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

  Future<void> _assign(BuildContext context, Period period, Slot? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SlotEditorSheet(
        weekday: _weekday,
        period: period,
        existing: existing,
      ),
    );
    await Notifications.instance.reschedule(ref.read(appProvider));
  }

  Future<void> _editPeriods(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _PeriodEditorSheet(),
    );
  }
}

class _PeriodRow extends ConsumerWidget {
  final Period period;
  final Slot? slot;
  final Slot? continuationOf;
  final VoidCallback onTap;

  const _PeriodRow({
    required this.period,
    required this.slot,
    required this.continuationOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);

    if (continuationOf != null) {
      final course = state.courseForComponent(continuationOf!.componentId);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                period.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Color(
                    course?.color ?? 0xFF64748B,
                  ).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 15,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'continues',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final course = slot == null
        ? null
        : state.courseForComponent(slot!.componentId);
    final component = slot == null
        ? null
        : state.componentById(slot!.componentId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  formatMinutes(period.startMin),
                  style: TextStyle(
                    fontSize: 10,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: slot == null
                      ? context.colors.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        )
                      : Color(course?.color ?? 0xFF64748B)
                            .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: slot == null
                      ? Border.all(
                          color: context.colors.outlineVariant,
                          style: BorderStyle.solid,
                        )
                      : null,
                ),
                child: slot == null
                    ? Row(
                        children: [
                          Icon(
                            Icons.add,
                            size: 16,
                            color: context.colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Free — tap to add',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course?.shortName ?? '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    if (slot!.isTutorial)
                                      'Tutorial'
                                    else
                                      component?.kind.label ?? '',
                                    if (slot!.spanPeriods > 1)
                                      '${slot!.spanPeriods} periods',
                                    if (slot!.batch != null) slot!.batch!,
                                  ].where((e) => e.isNotEmpty).join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotEditorSheet extends ConsumerStatefulWidget {
  final int weekday;
  final Period period;
  final Slot? existing;

  const _SlotEditorSheet({
    required this.weekday,
    required this.period,
    required this.existing,
  });

  @override
  ConsumerState<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends ConsumerState<_SlotEditorSheet> {
  late String? _componentId = widget.existing?.componentId;
  late int _span = widget.existing?.spanPeriods ?? 1;
  late bool _tutorial = widget.existing?.isTutorial ?? false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final components = state.enrolledComponents;

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
            '${weekdayName(widget.weekday)} · ${widget.period.label}',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.period.timeRange,
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
                  child: Text(
                    '${state.courseById(c.courseId)?.shortName ?? '?'} · '
                    '${c.kind.label}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _componentId = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Periods'),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _span > 1 ? () => setState(() => _span--) : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$_span',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _span < 4 ? () => setState(() => _span++) : null,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _tutorial,
            onChanged: (v) => setState(() => _tutorial = v),
            title: const Text('This one is a tutorial'),
            subtitle: const Text('Still counts into the same theory total'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.existing != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.risk.danger,
                  ),
                  onPressed: () {
                    ref
                        .read(appProvider.notifier)
                        .deleteSlot(widget.existing!.id);
                    Navigator.of(context).pop();
                  },
                ),
              const Spacer(),
              FilledButton(
                onPressed: _componentId == null ? null : _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final slot = Slot(
      id: widget.existing?.id ?? newId('s-'),
      componentId: _componentId!,
      weekday: widget.weekday,
      periodIndex: widget.period.index,
      spanPeriods: _span,
      isTutorial: _tutorial,
      batch: widget.existing?.batch,
      room: widget.existing?.room,
      units: _span,
    );
    ref.read(appProvider.notifier).upsertSlot(slot);
    Navigator.of(context).pop();
  }
}

class _PeriodEditorSheet extends ConsumerWidget {
  const _PeriodEditorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final periods = [...state.periods]
      ..sort((a, b) => a.index.compareTo(b.index));

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Period times',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set once. Every class anchors to a period, so changing a time here '
            'moves everything scheduled in it.',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final p in periods)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                child: Text(
                  '${p.index}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              title: Text(p.timeRange),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () async {
                final start = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: p.startMin ~/ 60,
                    minute: p.startMin % 60,
                  ),
                  helpText: 'Period ${p.index} starts',
                );
                if (start == null) return;
                if (!context.mounted) return;

                final end = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: p.endMin ~/ 60,
                    minute: p.endMin % 60,
                  ),
                  helpText: 'Period ${p.index} ends',
                );
                if (end == null) return;

                final updated = [
                  for (final x in state.periods)
                    if (x.index == p.index)
                      x.copyWith(
                        startMin: start.hour * 60 + start.minute,
                        endMin: end.hour * 60 + end.minute,
                      )
                    else
                      x,
                ];
                ref.read(appProvider.notifier).updatePeriods(updated);
              },
            ),
        ],
      ),
    );
  }
}
