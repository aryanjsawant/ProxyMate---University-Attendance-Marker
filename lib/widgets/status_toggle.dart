import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

/// The inline Present / Absent / Cancelled control.
///
/// This is the app's most-used widget and the reason marking is one tap. It is
/// always visible with **P preselected**, so the row already *is* the record —
/// there is nothing to confirm, and correcting it costs a single tap. No hidden
/// swipe gestures, nothing to discover.
///
/// Deliberately shared between Home and the day editor: correcting today and
/// correcting three weeks ago should feel like the same gesture.
class StatusToggle extends StatelessWidget {
  final Status value;
  final ValueChanged<Status> onChanged;

  /// Dims the control for classes that haven't happened yet. They stay tappable
  /// — you often know by breakfast that you're skipping the 2 o'clock.
  final bool dimmed;

  final bool compact;

  const StatusToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.dimmed = false,
    this.compact = false,
  });

  static const _options = [
    (Status.present, 'P', 'Present'),
    (Status.absent, 'A', 'Absent'),
    (Status.cancelled, 'C', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final height = compact ? 32.0 : 38.0;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (status, short, label) in _options)
              _Segment(
                label: short,
                semanticLabel: label,
                selected: value == status,
                color: statusColor(context, status),
                compact: compact,
                onTap: () => onChanged(status),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool selected;
  final Color color;
  final bool compact;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.color,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = compact ? 36.0 : 44.0;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          width: width,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : context.colors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
