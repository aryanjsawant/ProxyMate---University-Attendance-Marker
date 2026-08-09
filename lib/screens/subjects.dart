import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/stats.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/standing_row.dart';
import 'subject_detail.dart';

/// One card per **component**, grouped under its course.
///
/// ILLM Theory and ILLM Lab are separate cards with separate numbers because
/// that is how the university enforces them — pooling them would let a healthy
/// lecture percentage hide a failing lab.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final stats = ref.watch(allStatsProvider);

    // Group components by course, keeping courses ordered by their worst
    // component so trouble floats to the top of the screen.
    final byCourse = <String, List<ComponentStats>>{};
    for (final s in stats) {
      final comp = state.componentById(s.componentId);
      if (comp == null) continue;
      (byCourse[comp.courseId] ??= []).add(s);
    }

    final courseIds = byCourse.keys.toList()
      ..sort((a, b) {
        final wa = byCourse[a]!.first.risk.index;
        final wb = byCourse[b]!.first.risk.index;
        return wb.compareTo(wa);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      body: courseIds.isEmpty
          ? Center(
              child: Text(
                'No subjects yet.',
                style: TextStyle(color: context.colors.onSurfaceVariant),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                for (final courseId in courseIds) ...[
                  _CourseGroup(
                    course: state.courseById(courseId),
                    components: byCourse[courseId]!
                      ..sort(
                        (a, b) => _kindOrder(
                          state.componentById(a.componentId)?.kind,
                        ).compareTo(
                          _kindOrder(state.componentById(b.componentId)?.kind),
                        ),
                      ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
    );
  }

  static int _kindOrder(ComponentKind? k) =>
      k == ComponentKind.theory ? 0 : 1;
}

class _CourseGroup extends ConsumerWidget {
  final Course? course;
  final List<ComponentStats> components;

  const _CourseGroup({required this.course, required this.components});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(course?.color ?? 0xFF64748B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  course?.name ?? 'Unknown course',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (course?.code != null)
                Text(
                  course!.code!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < components.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                _ComponentTile(stats: components[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ComponentTile extends ConsumerWidget {
  final ComponentStats stats;
  const _ComponentTile({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final component = state.componentById(stats.componentId);
    final colour = context.risk.of(stats.risk);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubjectDetailScreen(componentId: stats.componentId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  component?.kind.label ?? 'Component',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  stats.hasData ? '${(stats.percent! * 100).round()}%' : '—',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colour,
                  ),
                ),
                const SizedBox(width: 6),
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
                      : 'not started',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [],
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
