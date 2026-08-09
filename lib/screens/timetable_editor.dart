import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/notifications.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'subject_editor.dart';

/// One weekday at a time, as a plain list of classes.
///
/// There is no period grid: a timetable entry is just a subject on a day with
/// an optional time, and **one entry is one attendance**. A subject that meets
/// twice on a Tuesday is simply added twice. That removes the whole bell-
/// schedule concept, which only ever made sense for colleges that have one.
class TimetableEditor extends ConsumerStatefulWidget {
  const TimetableEditor({super.key});

  @override
  ConsumerState<TimetableEditor> createState() => _TimetableEditorState();
}

class _TimetableEditorState extends ConsumerState<TimetableEditor> {
  late int _weekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final dayEnd = state.settings.dayEndsAtMinutes;

    final daySlots =
        state.activeSlots.where((s) => s.weekday == _weekday).toList()
          ..sort((a, b) => a.sortKey(dayEnd).compareTo(b.sortKey(dayEnd)));

    final hasAnySlots = state.activeSlots.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly timetable'),
        actions: [
          if (hasAnySlots)
            PopupMenuButton<int>(
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: 'Copy this day to…',
              onSelected: (to) async {
                ref.read(appProvider.notifier).copyDay(_weekday, to);
                await Notifications.instance.reschedule(ref.read(appProvider));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied to ${weekdayName(to)}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                  if (d != _weekday)
                    PopupMenuItem(
                      value: d,
                      child: Text('Copy to ${weekdayName(d)}'),
                    ),
              ],
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
                    child: _DayChip(
                      weekday: d,
                      count: state.activeSlots
                          .where((s) => s.weekday == d)
                          .length,
                      selected: _weekday == d,
                      onTap: () => setState(() => _weekday = d),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: !state.hasSubjects
                ? _NoSubjectsYet(onAdd: () => showSubjectEditor(context, null))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (daySlots.isEmpty)
                        _EmptyDay(weekday: _weekday)
                      else
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < daySlots.length; i++) ...[
                                if (i > 0)
                                  const Divider(indent: 16, endIndent: 16),
                                _SlotTile(
                                  slot: daySlots[i],
                                  onTap: () =>
                                      _editSlot(context, daySlots[i]),
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
                          label: Text('Add class on ${weekdayName(_weekday)}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _editSlot(context, null),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _Hint(
                        'Same subject twice in a day? Add it twice — each entry '
                        'counts as one attendance.',
                      ),
                      const SizedBox(height: 8),
                      _Hint(
                        'Time is optional. Classes without one are marked '
                        'present at your end-of-day time '
                        '(${formatMinutes(dayEnd)}), which you can change in '
                        'More.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSlot(BuildContext context, Slot? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SlotEditorSheet(weekday: _weekday, existing: existing),
    );
    await Notifications.instance.reschedule(ref.read(appProvider));
  }
}

class _DayChip extends StatelessWidget {
  final int weekday;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.weekday,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(weekdayShort(weekday)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.onSecondaryContainer.withValues(alpha: 0.18)
                  : context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
    selected: selected,
    onSelected: (_) => onTap(),
  );
}

class _SlotTile extends ConsumerWidget {
  final Slot slot;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(appProvider).subjectById(slot.subjectId);

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: Color(subject?.color ?? 0xFF64748B),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        subject?.name ?? 'Unknown subject',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Icon(
            slot.isTimed ? Icons.schedule : Icons.schedule_outlined,
            size: 13,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            slot.timeLabel,
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: slot.isTimed ? FontStyle.normal : FontStyle.italic,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (slot.room != null) ...[
            const SizedBox(width: 10),
            Icon(
              Icons.place_outlined,
              size: 13,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                slot.room!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: onTap,
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final int weekday;
  const _EmptyDay({required this.weekday});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 30,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No classes on ${weekdayName(weekday)}',
              style: TextStyle(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NoSubjectsYet extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoSubjectsYet({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 36,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            'Add a subject first',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A timetable is subjects placed on days, so it needs at least one '
            'subject to work with.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add subject'),
            onPressed: onAdd,
          ),
        ],
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.info_outline,
        size: 14,
        color: context.colors.onSurfaceVariant,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            height: 1.45,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class _SlotEditorSheet extends ConsumerStatefulWidget {
  final int weekday;
  final Slot? existing;

  const _SlotEditorSheet({required this.weekday, required this.existing});

  @override
  ConsumerState<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends ConsumerState<_SlotEditorSheet> {
  late String? _subjectId = widget.existing?.subjectId;
  late int? _start = widget.existing?.startMin;
  late int? _end = widget.existing?.endMin;
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  bool _showRoom = false;

  @override
  void initState() {
    super.initState();
    _showRoom = (widget.existing?.room ?? '').isNotEmpty;
    // With exactly one subject there is nothing to choose; preselect it.
    final subjects = ref.read(appProvider).subjects;
    if (_subjectId == null && subjects.length == 1) {
      _subjectId = subjects.first.id;
    }
  }

  @override
  void dispose() {
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final subjects = state.subjects;
    final dayEnd = state.settings.dayEndsAtMinutes;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? 'Add class · ${weekdayName(widget.weekday)}'
                  : 'Edit class · ${weekdayName(widget.weekday)}',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final s in subjects)
                  DropdownMenuItem(
                    value: s.id,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color(s.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: 18),
            Text(
              'TIME (OPTIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'Starts',
                    value: _start,
                    onPick: (m) => setState(() {
                      _start = m;
                      // Default an hour-long class; the user can change or
                      // clear the end.
                      _end ??= (m + 60) % (24 * 60);
                    }),
                    onClear: () => setState(() {
                      _start = null;
                      _end = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: 'Ends',
                    value: _end,
                    enabled: _start != null,
                    onPick: (m) => setState(() => _end = m),
                    onClear: () => setState(() => _end = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _start == null
                  ? 'No time set — this class is marked present at '
                        '${formatMinutes(dayEnd)}, your end of day.'
                  : 'Marked present once it ends. A two-hour class is still '
                        'one attendance.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!_showRoom)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add room (optional)'),
                onPressed: () => setState(() => _showRoom = true),
              )
            else
              TextField(
                controller: _room,
                decoration: const InputDecoration(
                  labelText: 'Room (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 20),
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
                  onPressed: _subjectId == null ? null : _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final room = _room.text.trim();
    ref
        .read(appProvider.notifier)
        .upsertSlot(
          Slot(
            id: widget.existing?.id ?? newId('s-'),
            subjectId: _subjectId!,
            weekday: widget.weekday,
            startMin: _start,
            endMin: _start == null ? null : _end,
            room: room.isEmpty ? null : room,
          ),
        );
    Navigator.of(context).pop();
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final int? value;
  final bool enabled;
  final ValueChanged<int> onPick;
  final VoidCallback onClear;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: !enabled
        ? null
        : () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value == null
                  ? const TimeOfDay(hour: 9, minute: 0)
                  : TimeOfDay(hour: value! ~/ 60, minute: value! % 60),
              helpText: label,
            );
            if (picked != null) onPick(picked.hour * 60 + picked.minute);
          },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
        suffixIcon: value == null
            ? const Icon(Icons.schedule, size: 18)
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: onClear,
              ),
      ),
      child: Text(
        value == null ? 'Not set' : formatMinutes(value!),
        style: TextStyle(
          color: value == null || !enabled
              ? context.colors.onSurfaceVariant
              : context.colors.onSurface,
        ),
      ),
    ),
  );
}
