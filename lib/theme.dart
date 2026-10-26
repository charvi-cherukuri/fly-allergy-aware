import 'package:flutter/material.dart';

import 'models/verdict.dart';

/// Trace's palette.
///
/// Dark mode is a first-class target, not an afterthought — competing apps get
/// called out in reviews for lacking it, which matters more than usual here
/// because a large share of users reach for these apps precisely because they
/// struggle to read small print on packaging.
class TraceColors {
  static const seed = Color(0xFF00695C);

  // Verdict colors. Deliberately not a plain red/amber/green traffic light:
  // caution has to read as its own answer, not a weak green.
  static const unsafe = Color(0xFFD32F2F);
  static const unsafeDark = Color(0xFFEF5350);
  static const caution = Color(0xFFE07A00);
  static const cautionDark = Color(0xFFFFB74D);
  static const unknown = Color(0xFF5C6BC0);
  static const unknownDark = Color(0xFF9FA8DA);
  static const clear = Color(0xFF2E7D32);
  static const clearDark = Color(0xFF66BB6A);

  static Color forLevel(VerdictLevel level, Brightness b) {
    final dark = b == Brightness.dark;
    switch (level) {
      case VerdictLevel.unsafe:
        return dark ? unsafeDark : unsafe;
      case VerdictLevel.caution:
        return dark ? cautionDark : caution;
      case VerdictLevel.unknown:
        return dark ? unknownDark : unknown;
      case VerdictLevel.clear:
        return dark ? clearDark : clear;
    }
  }

  static IconData iconForLevel(VerdictLevel level) {
    switch (level) {
      case VerdictLevel.unsafe:
        return Icons.dangerous_rounded;
      case VerdictLevel.caution:
        return Icons.warning_amber_rounded;
      case VerdictLevel.unknown:
        return Icons.help_outline_rounded;
      case VerdictLevel.clear:
        return Icons.check_circle_outline_rounded;
    }
  }

  /// The word shown on the verdict banner.
  ///
  /// The positive case says "No match found", never "Safe". The app is asserting
  /// the absence of a match in the data it holds — not the safety of the food.
  static String titleForLevel(VerdictLevel level) {
    switch (level) {
      case VerdictLevel.unsafe:
        return 'Do not eat';
      case VerdictLevel.caution:
        return 'Cross-contact risk';
      case VerdictLevel.unknown:
        return "Can't verify";
      case VerdictLevel.clear:
        return 'No match found';
    }
  }
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: TraceColors.seed,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 1,
      thickness: 1,
    ),
  );
}

/// Section header used across the app.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
