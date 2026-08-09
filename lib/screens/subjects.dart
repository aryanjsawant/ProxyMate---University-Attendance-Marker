import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/schedule.dart';
import '../logic/stats.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/standing_row.dart';
import 'subject_detail.dart';
import 'subject_editor.dart';

/// One card per subject, worst first.
///
/// Labs are ordinary subjects here — there is no course/component nesting,
/// because colleges enforce a separate percentage per registration line and
/// nesting them only ever invited pooling.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final stats = ref.watch(allStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: state.hasSubjects
          ? FloatingActionButton.extended(
              onPressed: () => showSubjectEditor(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Subject'),
            )
          : null,
      body: stats.isEmpty
          ? _NoSubjects(onAdd: () => showSubjectEditor(context, null))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                for (final s in stats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SubjectCard(stats: s),
                  ),
              ],
            ),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  final SubjectStats stats;
  const _SubjectCard({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final subject = state.subjectById(stats.subjectId);
    final colour = context.risk.of(stats.risk);
    final perWeek = weeklyUnits(state, stats.subjectId);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubjectDetailScreen(subjectId: stats.subjectId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(subject?.color ?? 0xFF64748B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subject?.name ?? 'Unknown subject',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    stats.hasData ? '${(stats.percent! * 100).round()}%' : '—',
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colour,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AttendanceBar(stats: stats),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stats.headline,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: stats.risk == RiskLevel.danger
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: stats.risk == RiskLevel.danger
                            ? colour
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    stats.hasData
                        ? '${stats.attended}/${stats.held}'
                        : perWeek == 0
                        ? 'not on timetable'
                        : 'not started',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoSubjects extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoSubjects({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 40,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No subjects yet',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add each subject you want tracked. Labs count as their own '
            'subject — most colleges enforce a separate 75% on them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add your first subject'),
            onPressed: onAdd,
          ),
        ],
      ),
    ),
  );
}
