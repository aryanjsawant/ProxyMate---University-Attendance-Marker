import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/status_toggle.dart';

/// The how-it-works explanation, reachable from More after setup.
///
/// Kept as its own screen rather than living only inside the wizard, because
/// the P/A/C idea is the one thing people forget — and someone who skipped the
/// walkthrough on install still needs a way to find it.
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  Status _demo = Status.present;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How this app works')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'It assumes you went.',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Every class on your timetable is marked present the moment it '
            'ends. You never open the app to say you attended — only when you '
            'skipped.',
            style: TextStyle(
              color: context.colors.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'THE THREE BUTTONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '9:30 am',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const Text(
                          'Operating Systems',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  StatusToggle(
                    value: _demo,
                    onChanged: (s) => setState(() => _demo = s),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _Legend(
            letter: 'P',
            colour: context.risk.safe,
            title: 'Present',
            body:
                'Already selected. This is the default — you only change it '
                'when it is wrong.',
            active: _demo == Status.present,
          ),
          _Legend(
            letter: 'A',
            colour: context.risk.danger,
            title: 'Absent',
            body: 'You skipped it. Counts against your percentage.',
            active: _demo == Status.absent,
          ),
          _Legend(
            letter: 'C',
            colour: context.risk.unknown,
            title: 'Cancelled',
            body:
                'The class never happened. Counts against neither side, so it '
                'does not dent your percentage.',
            active: _demo == Status.cancelled,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _Tip(
            icon: Icons.touch_app_outlined,
            title: 'Long-press a class',
            body:
                'For a note, the room, or to make one session count as two — '
                'useful when a teacher takes attendance twice.',
          ),
          _Tip(
            icon: Icons.add_circle_outline,
            title: 'Extra classes',
            body:
                'Teachers hold classes off the timetable. Add one from Home or '
                'from any day in History; it counts exactly like a scheduled '
                'class.',
          ),
          _Tip(
            icon: Icons.schedule_outlined,
            title: 'Classes with no time',
            body:
                'A timetable entry does not need a time. Those get marked '
                'present at your end-of-day time, which you can change in More.',
          ),
          _Tip(
            icon: Icons.event_repeat_outlined,
            title: 'Two classes of one subject in a day',
            body:
                'Add it to that day twice. Each entry is one attendance, so a '
                'two-hour class is still just one.',
          ),
          _Tip(
            icon: Icons.beach_access_outlined,
            title: 'Holidays and breaks',
            body:
                'In History, open any day and use the menu to cancel a whole '
                'day or mark a date range as no-class.',
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String letter;
  final Color colour;
  final String title;
  final String body;
  final bool active;

  const _Legend({
    required this.letter,
    required this.colour,
    required this.title,
    required this.body,
    required this.active,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 160),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: active ? colour.withValues(alpha: 0.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
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

class _Tip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Tip({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: context.colors.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
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
