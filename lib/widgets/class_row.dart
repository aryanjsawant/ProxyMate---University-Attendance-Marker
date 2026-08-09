import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/schedule.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'status_toggle.dart';

/// One scheduled class on Home or in the day editor.
///
/// The row carries its own status control with P preselected, so the common
/// case — you went — costs nothing at all, and correcting it costs one tap.
class ClassRow extends ConsumerWidget {
  final Occurrence occurrence;
  final AttendanceRecord? record;
  final DateTime now;

  const ClassRow({
    super.key,
    required this.occurrence,
    required this.record,
    required this.now,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final slot = occurrence.slot;
    final component = state.componentById(slot.componentId);
    final course = state.courseForComponent(slot.componentId);
    final upcoming = !occurrence.hasElapsedAt(now);

    // Until a record exists the row still shows Present, because that is what
    // will be written the moment the class ends. The row is the record.
    final status = record?.status ?? Status.present;

    final subtitle = [
      if (slot.isTutorial)
        'Tutorial'
      else
        component?.kind.label ?? 'Class',
      if (slot.units > 1) '${slot.units} periods',
      if (slot.batch != null) slot.batch!,
    ].join(' · ');

    return InkWell(
      onLongPress: () => _showDetailSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Color(course?.color ?? 0xFF64748B)
                    .withValues(alpha: upcoming ? 0.4 : 1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMinutes(occurrence.startPeriod.startMin),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    course?.shortName ?? 'Class',
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusToggle(
              value: status,
              dimmed: upcoming && record == null,
              onChanged: (s) => _setStatus(context, ref, s),
            ),
          ],
        ),
      ),
    );
  }

  void _setStatus(BuildContext context, WidgetRef ref, Status status) {
    final previous = record;
    ref.read(appProvider.notifier).setOccurrenceStatus(occurrence, status);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Marked ${status.label.toLowerCase()}'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final notifier = ref.read(appProvider.notifier);
            if (previous == null) {
              // Nothing existed before; find what we just wrote and drop it.
              final created = ref
                  .read(appProvider)
                  .records
                  .where(
                    (r) =>
                        r.slotId == occurrence.slot.id &&
                        dateOnly(r.date) == occurrence.date,
                  )
                  .toList();
              for (final r in created) {
                notifier.deleteRecord(r.id);
              }
            } else {
              notifier.updateRecord(previous);
            }
          },
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ClassDetailSheet(occurrence: occurrence, record: record),
    );
  }
}

/// Long-press target: unit count, note, room and faculty — everything that
/// would clutter the row if it were always visible.
class ClassDetailSheet extends ConsumerStatefulWidget {
  final Occurrence occurrence;
  final AttendanceRecord? record;

  const ClassDetailSheet({
    super.key,
    required this.occurrence,
    required this.record,
  });

  @override
  ConsumerState<ClassDetailSheet> createState() => _ClassDetailSheetState();
}

class _ClassDetailSheetState extends ConsumerState<ClassDetailSheet> {
  late int _units = widget.record?.units ?? widget.occurrence.slot.units;
  late final _noteController = TextEditingController(
    text: widget.record?.note ?? '',
  );

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final slot = widget.occurrence.slot;
    final course = state.courseForComponent(slot.componentId);
    final component = state.componentById(slot.componentId);

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
            '${course?.shortName ?? 'Class'} · '
            '${slot.isTutorial ? 'Tutorial' : component?.kind.label ?? ''}',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatLongDate(widget.occurrence.date)} · '
            '${widget.occurrence.timeRange}',
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          if (course?.faculty != null) ...[
            const SizedBox(height: 10),
            _MetaLine(icon: Icons.person_outline, text: course!.faculty!),
          ],
          if (slot.room != null || course?.venue != null) ...[
            const SizedBox(height: 6),
            _MetaLine(
              icon: Icons.place_outlined,
              text: slot.room ?? course!.venue!,
            ),
          ],
          const SizedBox(height: 20),
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
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'e.g. teacher took attendance twice',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.record != null)
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.risk.danger,
                  ),
                  onPressed: () {
                    ref
                        .read(appProvider.notifier)
                        .deleteRecord(widget.record!.id);
                    Navigator.of(context).pop();
                  },
                ),
              const Spacer(),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final notifier = ref.read(appProvider.notifier);
    final existing = widget.record;
    final note = _noteController.text.trim();

    if (existing != null) {
      notifier.updateRecord(
        existing.copyWith(
          units: _units,
          note: note.isEmpty ? null : note,
          isManual: true,
        ),
      );
    } else {
      notifier.setOccurrenceUnits(widget.occurrence, _units);
    }
    Navigator.of(context).pop();
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: context.colors.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

/// An ad-hoc class the teacher added. It has no slot behind it, so it renders
/// with its own affordances but counts identically.
class ExtraClassRow extends ConsumerWidget {
  final AttendanceRecord record;
  const ExtraClassRow({super.key, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final course = state.courseForComponent(record.componentId);
    final component = state.componentById(record.componentId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Color(course?.color ?? 0xFF64748B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'EXTRA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  course?.shortName ?? 'Class',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  [
                    component?.kind.label ?? '',
                    if (record.units > 1) '${record.units} periods',
                    if (record.note != null) record.note!,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusToggle(
            value: record.status,
            onChanged: (s) => ref
                .read(appProvider.notifier)
                .updateRecord(record.copyWith(status: s, isManual: true)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                ref.read(appProvider.notifier).deleteRecord(record.id),
          ),
        ],
      ),
    );
  }
}
