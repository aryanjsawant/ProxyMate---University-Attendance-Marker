import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'logic/stats.dart';
import 'models/models.dart';

const seedColor = Color(0xFF4F46E5);

/// Risk colours are the app's core vocabulary: green means slack, amber means
/// you're inside the last five points, red means you're already under. They are
/// used identically on Home, Subjects and History so the colour alone carries
/// meaning without a legend.
class RiskColors {
  final Color safe;
  final Color warning;
  final Color danger;
  final Color unknown;

  const RiskColors({
    required this.safe,
    required this.warning,
    required this.danger,
    required this.unknown,
  });

  static const light = RiskColors(
    safe: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    unknown: Color(0xFF94A3B8),
  );

  static const dark = RiskColors(
    safe: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    unknown: Color(0xFF64748B),
  );

  Color of(RiskLevel level) => switch (level) {
    RiskLevel.safe => safe,
    RiskLevel.warning => warning,
    RiskLevel.danger => danger,
    RiskLevel.unknown => unknown,
  };
}

extension RiskTheme on BuildContext {
  RiskColors get risk => Theme.of(this).brightness == Brightness.dark
      ? RiskColors.dark
      : RiskColors.light;

  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Status colours reuse the risk vocabulary: present is the safe green, absent
/// the danger red, cancelled a neutral grey — so a row reads the same way as
/// the subject card it feeds.
Color statusColor(BuildContext context, Status status) => switch (status) {
  Status.present => context.risk.safe,
  Status.absent => context.risk.danger,
  Status.cancelled => context.risk.unknown,
};

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  // AppBarTheme.titleTextStyle *replaces* the default text style rather than
  // merging with it, so a bare TextStyle here would drop the theme's font
  // family and fall back to whatever the platform picks. Derive it from the
  // typography instead.
  final baseTitle = Typography.material2021(
    platform: defaultTargetPlatform,
    colorScheme: scheme,
  );
  final titleStyle =
      (brightness == Brightness.dark
              ? baseTitle.white
              : baseTitle.black)
          .titleLarge
          ?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.dark
        ? const Color(0xFF0B1120)
        : const Color(0xFFF8FAFC),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: brightness == Brightness.dark
          ? const Color(0xFF151D2E)
          : Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: titleStyle,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  );
}
