import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/schedule.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'subject_editor.dart';

/// Add, edit and remove subjects in one place.
///
/// Reachable from More and from the setup wizard. Shows how many timetable
/// entries each subject has, because "why is this subject never marked?" is
/// almost always "it isn't on the timetable".
Future<void> showSubjectManager(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const SubjectManagerScreen()),
  );
}

class SubjectManagerScreen extends ConsumerWidget {
  const SubjectManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final subjects = state.subjects;

    return Scaffold(
      appBar: AppBar(title: const Text('Subjects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSubjectEditor(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Subject'),
      ),
      body: subjects.isEmpty
          ? Center(
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
                    const SizedBox(height: 12),
                    Text(
                      'No subjects yet',
                      style: TextStyle(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < subjects.length; i++) ...[
                        if (i > 0) const Divider(indent: 16, endIndent: 16),
                        Builder(
                          builder: (context) {
                            final s = subjects[i];
                            final perWeek = weeklyUnits(state, s.id);
                            return ListTile(
                              leading: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Color(s.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  perWeek == 0
                                      ? 'Not on the timetable'
                                      : '$perWeek a week',
                                  if (s.faculty != null) s.faculty!,
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: perWeek == 0
                                      ? context.risk.warning
                                      : null,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                              ),
                              onTap: () => showSubjectEditor(context, s),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
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
                        'Deleting a subject also removes its timetable entries '
                        'and its attendance history. You will be told exactly '
                        'what goes before it happens.',
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
            ),
    );
  }
}
