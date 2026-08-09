import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/dates.dart';
import '../logic/stats.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'day_editor.dart';

/// The full arithmetic for one component, plus every record that isn't a plain
/// "present" — which is the only part of the history anyone actually scans.
class SubjectDetailScreen extends ConsumerWidget {
  final String subjectId;
  const SubjectDetailScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final stats = ref.watch(statsForProvider(subjectId));
    final subject = state.subjectById(subjectId);
    final colour = context.risk.of(stats.risk);

    final exceptions =
        state.records
            .where((r) => r.subjectId == subjectId)
            .where((r) => r.status != Status.present)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(subject?.name ?? 'Subject'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Hero(stats: stats, colour: colour),
          const SizedBox(height: 20),
          _CountsCard(stats: stats, subjectId: subjectId),
          const SizedBox(height: 16),
          _ProjectionCard(stats: stats),
          const SizedBox(height: 24),
          Text(
            exceptions.isEmpty
                ? 'NOTHING MISSED YET'
                : 'MISSED & CANCELLED (${exceptions.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          if (exceptions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Every class so far is marked present.',
                    style: TextStyle(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < exceptions.length; i++) ...[
                    if (i > 0) const Divider(indent: 16, endIndent: 16),
                    _ExceptionTile(record: exceptions[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final SubjectStats stats;
  final Color colour;
  const _Hero({required this.stats, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (stats.percent ?? 0).clamp(0.0, 1.0),
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      backgroundColor: context.colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colour),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stats.hasData
                            ? '${(stats.percent! * 100).round()}%'
                            : '—',
                        style: context.text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colour,
                        ),
                      ),
                      Text(
                        'target ${(stats.target * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              stats.headline,
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: stats.risk == RiskLevel.danger ? colour : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountsCard extends ConsumerWidget {
  final SubjectStats stats;
  final String subjectId;
  const _CountsCard({required this.stats, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Stat(label: 'Attended', value: '${stats.attended}'),
            _Stat(label: 'Missed', value: '${stats.missed}'),
            _Stat(
              label: 'Held so far',
              value: '${stats.held}',
              hint: 'cancelled classes are excluded',
            ),
            _Stat(
              label: 'Cancelled',
              value: '${stats.cancelled}',
              hint: 'counts against neither side',
            ),
            const Divider(height: 24),
            _Stat(
              label: 'Can miss right now',
              value: '${stats.canMissNow}',
              bold: true,
            ),
            if (!stats.isAtTarget && stats.hasData)
              _Stat(
                label: 'Must attend in a row',
                value: '${stats.mustAttendNow}',
                bold: true,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'One timetable entry counts as one class.',
                style: TextStyle(
                  fontSize: 11,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything here needs a term end date. Without one the app says so plainly
/// rather than guessing a semester length.
class _ProjectionCard extends ConsumerWidget {
  final SubjectStats stats;
  const _ProjectionCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stats.remaining == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set a semester end date to see the projected total and how '
                  'many classes you can miss for the rest of the term.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Stat(label: 'Still to come', value: '${stats.remaining}'),
            _Stat(
              label: 'Projected semester total',
              value: '${stats.projectedTotal}',
            ),
            if (stats.isTargetUnreachable) ...[
              const Divider(height: 24),
              _Stat(
                label: 'Best you can still reach',
                value: '${(stats.bestAchievable! * 100).round()}%',
                bold: true,
                colour: context.risk.danger,
              ),
              _Stat(
                label: 'Extra classes needed',
                value: '${stats.extraClassesNeeded}',
                hint: 'beyond the timetable',
              ),
            ] else ...[
              const Divider(height: 24),
              _Stat(
                label: 'Can miss for the whole rest of term',
                value: '${stats.canMissRestOfTerm}',
                bold: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;
  final bool bold;
  final Color? colour;

  const _Stat({
    required this.label,
    required this.value,
    this.hint,
    this.bold = false,
    this.colour,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (hint != null)
                Text(
                  hint!,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: colour,
          ),
        ),
      ],
    ),
  );
}

class _ExceptionTile extends ConsumerWidget {
  final AttendanceRecord record;
  const _ExceptionTile({required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final slot = record.slotId == null ? null : state.slotById(record.slotId!);
    final colour = statusColor(context, record.status);

    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
      ),
      title: Text(formatShortDate(record.date)),
      subtitle: Text(
        [
          record.status.label,
          if (slot != null && slot.isTimed) formatMinutes(slot.startMin!),
          if (record.slotId == null) 'extra class',
          if (record.units > 1) '${record.units} periods',
          if (record.note != null) record.note!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayEditorScreen(date: record.date)),
      ),
    );
  }
}
