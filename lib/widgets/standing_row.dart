import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/stats.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';

/// One component's standing, reduced to a percentage and **a single actionable
/// line**.
///
/// The full arithmetic (projected total, best achievable, whole-term budget)
/// lives on the detail screen. Putting five numbers on a card is what makes
/// other attendance apps read like spreadsheets.
class StandingRow extends ConsumerWidget {
  final ComponentStats stats;
  final VoidCallback? onTap;

  const StandingRow({
    super.key,
    required this.stats,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    final component = state.componentById(stats.componentId);
    final course = state.courseForComponent(stats.componentId);

    final colour = context.risk.of(stats.risk);
    // Only trouble is coloured, so the eye lands on it rather than scanning.
    final emphasise = stats.risk == RiskLevel.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: emphasise
                    ? colour
                    : colour.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${course?.shortName ?? '?'} '
                          '${component?.kind.label ?? ''}',
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stats.hasData
                            ? '${(stats.percent! * 100).round()}%'
                            : '—',
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: emphasise ? colour : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stats.headline,
                    style: TextStyle(
                      fontSize: 12,
                      color: stats.risk == RiskLevel.danger
                          ? colour
                          : context.colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// A slim progress bar used on the Subjects cards.
class AttendanceBar extends StatelessWidget {
  final ComponentStats stats;
  const AttendanceBar({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final colour = context.risk.of(stats.risk);
    final value = stats.percent ?? 0;

    return Stack(
      children: [
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: colour,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        // The target line, so "how far above/below the bar am I" is visible
        // without reading the number.
        Positioned(
          left: 0,
          right: 0,
          child: FractionallySizedBox(
            widthFactor: stats.target.clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 2,
                height: 6,
                color: context.colors.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
