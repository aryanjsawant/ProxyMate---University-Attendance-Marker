import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/attendance.dart' as engine;
import '../logic/dates.dart';
import '../logic/schedule.dart';
import '../logic/stats.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/class_row.dart';
import '../widgets/standing_row.dart';
import 'day_editor.dart';
import 'subject_detail.dart';

/// Home merges status and marking into one screen: today's classes on top, a
/// divider, then how every other subject stands.
///
/// The ordering is deliberate. You open this app for two reasons — "am I safe?"
/// and "I bunked, log it" — and today's rows answer the second in one tap while
/// the standings below answer the first without any tap at all.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final now = ref.watch(clockProvider);
    final today = ref.watch(todayProvider);
    final stats = ref.watch(allStatsProvider);
    final extras = engine.dayView(state, now).extras;

    return Scaffold(
      appBar: AppBar(
        title: Text(formatLongDate(now)),
        actions: [
          IconButton(
            tooltip: 'Edit today in full',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DayEditorScreen(date: now)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _SectionLabel('TODAY'),
          const SizedBox(height: 8),
          _TodayCard(occurrences: today, extras: extras, now: now),
          const SizedBox(height: 12),
          _AddExtraButton(date: now),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          _Standings(stats: stats),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: context.colors.onSurfaceVariant,
    ),
  );
}

class _TodayCard extends ConsumerWidget {
  final List<Occurrence> occurrences;
  final List<AttendanceRecord> extras;
  final DateTime now;

  const _TodayCard({
    required this.occurrences,
    required this.extras,
    required this.now,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (occurrences.isEmpty && extras.isEmpty) {
      return const _EmptyToday();
    }

    final state = ref.watch(appProvider);

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < occurrences.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ClassRow(
              occurrence: occurrences[i],
              record: engine.recordForOccurrence(state, occurrences[i]),
              now: now,
            ),
          ],
          for (var i = 0; i < extras.length; i++) ...[
            if (i > 0 || occurrences.isNotEmpty)
              const Divider(indent: 16, endIndent: 16),
            ExtraClassRow(record: extras[i]),
          ],
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.free_breakfast_outlined,
              size: 32,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No classes today',
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enjoy it.',
              style: TextStyle(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AddExtraButton extends StatelessWidget {
  final DateTime date;
  const _AddExtraButton({required this.date});

  @override
  Widget build(BuildContext context) => SizedBox(
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
      onPressed: () => showAddExtraClassSheet(context, date),
    ),
  );
}

/// At-risk components sort to the top and are the only ones coloured; the safe
/// ones stay a quiet list. Capped so Home never becomes a wall of numbers.
class _Standings extends StatefulWidget {
  final List<ComponentStats> stats;
  const _Standings({required this.stats});

  @override
  State<_Standings> createState() => _StandingsState();
}

class _StandingsState extends State<_Standings> {
  static const _collapsedCount = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.stats.isEmpty) {
      return Text(
        'No subjects yet.',
        style: TextStyle(color: context.colors.onSurfaceVariant),
      );
    }

    final showAll = _expanded || widget.stats.length <= _collapsedCount;
    final visible = showAll
        ? widget.stats
        : widget.stats.take(_collapsedCount).toList();
    final hidden = widget.stats.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('WHERE YOU STAND'),
        const SizedBox(height: 12),
        for (final s in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StandingRow(
              stats: s,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubjectDetailScreen(componentId: s.componentId),
                ),
              ),
            ),
          ),
        if (hidden > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text('See all ${widget.stats.length} ›'),
            ),
          ),
      ],
    );
  }
}
