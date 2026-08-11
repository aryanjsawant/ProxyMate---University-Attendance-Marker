import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../logic/dates.dart';
import '../logic/notifications.dart';
import '../state/providers.dart';
import '../theme.dart';
import 'subject_manager.dart';
import 'timetable_editor.dart';
import 'walkthrough.dart';

/// Everything you touch rarely. Timetable sits at the top because teachers do
/// change the schedule mid-semester.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final term = state.term;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Group(
            label: 'TIMETABLE',
            children: [
              ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: const Text('Edit weekly timetable'),
                subtitle: Text('${state.activeSlots.length} classes a week'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TimetableEditor()),
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Subjects'),
                subtitle: Text(
                  state.subjects.isEmpty
                      ? 'None yet'
                      : state.subjects.map((s) => s.name).join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => showSubjectManager(context),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('How this app works'),
                subtitle: const Text('The P / A / C walkthrough again'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WalkthroughScreen()),
                ),
              ),
            ],
          ),
          _Group(
            label: 'SEMESTER',
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow_outlined),
                title: const Text('Start date'),
                trailing: Text(
                  term == null ? '—' : formatShortDate(term.startDate),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: term == null
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: term.startDate,
                          firstDate: DateTime(term.startDate.year - 2),
                          lastDate: DateTime(term.startDate.year + 2),
                        );
                        if (picked != null) {
                          ref
                              .read(appProvider.notifier)
                              .updateTerm(term.copyWith(startDate: picked));
                        }
                      },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('End date'),
                subtitle: const Text('Unlocks semester projections'),
                trailing: Text(
                  term?.endDate == null
                      ? 'Not set'
                      : formatShortDate(term!.endDate!),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: term == null
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              term.endDate ??
                              DateTime(
                                term.startDate.year,
                                term.startDate.month + 4,
                              ),
                          firstDate: term.startDate,
                          lastDate: DateTime(term.startDate.year + 2),
                        );
                        if (picked != null) {
                          ref
                              .read(appProvider.notifier)
                              .updateTerm(term.copyWith(endDate: picked));
                        }
                      },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.beach_access_outlined),
                title: const Text('Holidays'),
                subtitle: Text(
                  '${term?.holidays.length ?? 0} days excluded',
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: term == null
                    ? null
                    : () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: term.startDate,
                          lastDate: DateTime(term.startDate.year + 2),
                          helpText: 'Days with no classes',
                        );
                        if (picked != null) {
                          ref
                              .read(appProvider.notifier)
                              .markRangeAsNoClass(picked.start, picked.end);
                        }
                      },
              ),
              const Divider(indent: 16, endIndent: 16),
              _TargetTile(),
            ],
          ),
          _Group(
            label: 'NOTIFICATIONS',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('End-of-day check'),
                subtitle: Text(
                  'Fires ${state.settings.nudgeOffsetMinutes} min after your '
                  'last class',
                ),
                value: state.settings.nudgeEnabled,
                onChanged: (v) async {
                  if (v) await Notifications.instance.requestPermission();
                  final notifier = ref.read(appProvider.notifier);
                  notifier.updateSettings(
                    state.settings.copyWith(nudgeEnabled: v),
                  );
                  await Notifications.instance.reschedule(
                    ref.read(appProvider),
                  );
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Nudge delay'),
                trailing: DropdownButton<int>(
                  value: state.settings.nudgeOffsetMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('At end')),
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 120, child: Text('2 hours')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    ref
                        .read(appProvider.notifier)
                        .updateSettings(
                          state.settings.copyWith(nudgeOffsetMinutes: v),
                        );
                    await Notifications.instance.reschedule(
                      ref.read(appProvider),
                    );
                  },
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Day ends at'),
                subtitle: const Text(
                  'When classes with no time set are marked present',
                ),
                trailing: Text(
                  formatMinutes(state.settings.dayEndsAtMinutes),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final m = state.settings.dayEndsAtMinutes;
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
                    helpText: 'Your day ends at',
                  );
                  if (picked == null) return;
                  ref
                      .read(appProvider.notifier)
                      .updateSettings(
                        state.settings.copyWith(
                          dayEndsAtMinutes: picked.hour * 60 + picked.minute,
                        ),
                      );
                  await Notifications.instance.reschedule(
                    ref.read(appProvider),
                  );
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.calendar_view_week_outlined),
                title: const Text('Weekly summary'),
                subtitle: const Text('Sunday evening'),
                value: state.settings.weeklySummaryEnabled,
                onChanged: (v) async {
                  ref
                      .read(appProvider.notifier)
                      .updateSettings(
                        state.settings.copyWith(weeklySummaryEnabled: v),
                      );
                  await Notifications.instance.reschedule(ref.read(appProvider));
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.send_outlined),
                title: const Text('Send a test notification'),
                subtitle: const Text('Should arrive immediately'),
                onTap: () async {
                  await Notifications.instance.requestPermission();
                  await Notifications.instance.sendTest();
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              const _NotificationStatusTile(),
            ],
          ),
          _Group(
            label: 'BACKUP',
            children: [
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Export everything'),
                subtitle: const Text('One JSON file — records and timetable'),
                onTap: () => _export(context, ref),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import from a backup'),
                subtitle: const Text('Paste an exported file'),
                onTap: () => _showImportDialog(context, ref),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.restart_alt, color: context.risk.danger),
                title: Text(
                  'Reset everything',
                  style: TextStyle(color: context.risk.danger),
                ),
                onTap: () => _confirmReset(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ProxyMate · all data stays on this phone',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final store = ref.read(storeProvider);
    final file = await store.writeExport(ref.read(appProvider));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'ProxyMate backup',
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste the contents of an exported ProxyMate file. This replaces '
              'everything currently in the app.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{ "schemaVersion": 1, ... }',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!context.mounted) return;

    try {
      final imported = Store.decode(controller.text);
      ref.read(appProvider.notifier).applyImportedTimetable(imported);
      ref.read(appProvider.notifier).refreshNow();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Imported')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("That doesn't look like a backup")));
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
          'This deletes every attendance record and your timetable. It cannot '
          'be undone — export a backup first if you might want it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.risk.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(appProvider.notifier).resetEverything();
      await Notifications.instance.cancelAll();
    }
  }

}

class _Group extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Group({required this.label, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
      Card(child: Column(children: children)),
    ],
  );
}

class _TargetTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final target = state.term?.defaultTarget ?? 0.75;

    return ListTile(
      leading: const Icon(Icons.percent),
      title: const Text('Attendance target'),
      trailing: DropdownButton<double>(
        value: target,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 0.5, child: Text('50%')),
          DropdownMenuItem(value: 0.6, child: Text('60%')),
          DropdownMenuItem(value: 0.65, child: Text('65%')),
          DropdownMenuItem(value: 0.7, child: Text('70%')),
          DropdownMenuItem(value: 0.75, child: Text('75%')),
          DropdownMenuItem(value: 0.8, child: Text('80%')),
          DropdownMenuItem(value: 0.85, child: Text('85%')),
        ],
        onChanged: (v) {
          if (v == null || state.term == null) return;
          final notifier = ref.read(appProvider.notifier);
          notifier.updateTerm(state.term!.copyWith(defaultTarget: v));
          for (final s in state.subjects) {
            notifier.setTargetForSubject(s.id, v);
          }
        },
      ),
    );
  }
}

/// Makes a silent notification failure visible.
///
/// Everything about this feature happens outside the app — Android holds the
/// alarms and fires them with nothing of ours running — so when it breaks the
/// only symptom is that the user simply never hears from the app again. This
/// says whether the permission is granted and how many alarms Android is
/// actually holding.
class _NotificationStatusTile extends ConsumerStatefulWidget {
  const _NotificationStatusTile();

  @override
  ConsumerState<_NotificationStatusTile> createState() =>
      _NotificationStatusTileState();
}

class _NotificationStatusTileState
    extends ConsumerState<_NotificationStatusTile> {
  int? _pending;
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final pending = await Notifications.instance.pendingCount();
    final granted = await Notifications.instance.permissionGranted();
    if (mounted) {
      setState(() {
        _pending = pending;
        _granted = granted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    final error = Notifications.instance.lastError;

    final (IconData icon, Color colour, String text) = switch ((
      Notifications.instance.isReady,
      _granted,
      _pending,
    )) {
      (false, _, _) => (
        Icons.error_outline,
        context.risk.danger,
        'Could not start: ${error ?? 'unknown error'}',
      ),
      (_, false, _) => (
        Icons.notifications_off_outlined,
        context.risk.danger,
        'Blocked by Android — enable them in system settings',
      ),
      (_, _, final int n) when n == 0 && state.hasTimetable => (
        Icons.warning_amber_rounded,
        context.risk.warning,
        'Nothing scheduled. Try toggling the end-of-day check off and on.',
      ),
      (_, _, final int n) when n == 0 => (
        Icons.info_outline,
        context.colors.onSurfaceVariant,
        'Nothing scheduled yet — add a timetable first',
      ),
      (_, _, final int n) => (
        Icons.check_circle_outline,
        context.risk.safe,
        '$n scheduled and waiting',
      ),
      _ => (
        Icons.hourglass_empty,
        context.colors.onSurfaceVariant,
        'Checking…',
      ),
    };

    return ListTile(
      leading: Icon(icon, color: colour),
      title: const Text('Status'),
      subtitle: Text(text, style: TextStyle(color: colour)),
      trailing: IconButton(
        icon: const Icon(Icons.refresh, size: 18),
        onPressed: _refresh,
      ),
    );
  }
}
