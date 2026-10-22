import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nr_tokens.dart';
import 'nr_typography.dart';

/// Tema Material 3 construido solo con [NrColors] (claro, oscuro y alto contraste).
abstract final class NrTheme {
  static ThemeData light(Color accent, {bool highContrast = false}) => _build(NrColors.light(accent, highContrast), Brightness.light);
  static ThemeData dark(Color accent, {bool highContrast = false}) => _build(NrColors.dark(accent, highContrast), Brightness.dark);

  static ThemeData _build(NrColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const family = NrText.family;
    final hc = c.highContrast;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: isDark ? c.link : c.accent,
      secondary: c.ink,
      onSecondary: c.onInk,
      tertiary: c.success,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.dangerBg,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.body,
      onSurfaceVariant: c.secondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.raised,
      surfaceContainerHighest: c.raised,
      outline: c.borderStrong,
      outlineVariant: c.border,
      inverseSurface: c.ink,
      onInverseSurface: c.onInk,
      surfaceTint: Colors.transparent,
    );

    TextStyle t(double size, FontWeight w, Color color, {double ls = 0, double h = 1.3}) =>
        TextStyle(fontFamily: family, fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: h);

    final r12 = BorderRadius.circular(NrRadius.lg);
    final r14 = BorderRadius.circular(NrRadius.xl);
    final field = hc ? c.surface : (isDark ? c.raised : c.surface);
    final fieldBorder = BorderSide(color: hc ? c.borderStrong : c.borderStrong, width: hc ? 1.5 : 1);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: family,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: c.headline.withValues(alpha: 0.04),
      extensions: [c],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      cupertinoOverrideTheme: CupertinoThemeData(primaryColor: c.accent, brightness: brightness),
      textTheme: TextTheme(
        headlineMedium: t(24, FontWeight.w700, c.headline, ls: -0.6),
        headlineSmall: t(20, FontWeight.w700, c.headline, ls: -0.4),
        titleLarge: t(18, FontWeight.w600, c.headline, ls: -0.3),
        titleMedium: t(16, FontWeight.w600, c.headline, ls: -0.2),
        titleSmall: t(14, FontWeight.w600, c.headline),
        bodyLarge: t(16, FontWeight.w400, c.body, h: 1.45),
        bodyMedium: t(14, FontWeight.w400, c.body, h: 1.4),
        bodySmall: t(12, FontWeight.w400, c.secondary),
        labelLarge: t(14, FontWeight.w500, c.body),
        labelMedium: t(12, FontWeight.w500, c.secondary),
        labelSmall: t(11, FontWeight.w500, c.secondary, ls: 0.4),
      ),
      iconTheme: IconThemeData(color: c.secondary, size: 22),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        backgroundColor: c.canvas,
        foregroundColor: c.headline,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: t(17, FontWeight.w700, c.headline, ls: -0.3),
        iconTheme: IconThemeData(color: c.headline, size: 22),
        actionsIconTheme: IconThemeData(color: c.headline, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.xxl), side: BorderSide(color: c.border)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: hc ? 1.2 : 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: t(15, FontWeight.w400, c.muted),
        labelStyle: t(14, FontWeight.w500, c.secondary),
        floatingLabelStyle: t(13, FontWeight.w600, isDark ? c.link : c.accent),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        border: OutlineInputBorder(borderRadius: r14, borderSide: fieldBorder),
        enabledBorder: OutlineInputBorder(borderRadius: r14, borderSide: isDark && !hc ? BorderSide(color: c.border) : fieldBorder),
        focusedBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: c.accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: r14, borderSide: BorderSide(color: c.danger, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.raised,
          disabledForegroundColor: c.muted,
          minimumSize: const Size(64, NrTouch.min),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: r14),
          textStyle: t(15, FontWeight.w600, c.onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.headline,
          backgroundColor: c.surface,
          minimumSize: const Size(64, NrTouch.min),
          side: BorderSide(color: c.borderStrong, width: hc ? 1.5 : 1),
          shape: RoundedRectangleBorder(borderRadius: r14),
          textStyle: t(15, FontWeight.w600, c.headline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.link, minimumSize: const Size(48, 44), textStyle: t(14, FontWeight.w600, c.link)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: c.headline)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.xxl)),
        extendedTextStyle: t(15, FontWeight.w600, c.onAccent),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        side: BorderSide(color: hc ? c.borderStrong : c.border),
        labelStyle: t(14, FontWeight.w500, c.body),
        secondaryLabelStyle: t(14, FontWeight.w600, c.onInk),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.pill)),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.secondary,
        minVerticalPadding: 12,
        titleTextStyle: t(15, FontWeight.w500, c.headline),
        subtitleTextStyle: t(13, FontWeight.w400, c.secondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : (isDark ? c.secondary : Colors.white)),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : (isDark ? c.raised : c.sunken)),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : c.borderStrong),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.raised, circularTrackColor: Colors.transparent),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        dragHandleSize: const Size(40, 5),
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.35),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NrRadius.hero))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.hero)),
        titleTextStyle: t(19, FontWeight.w700, c.headline, ls: -0.4),
        contentTextStyle: t(15, FontWeight.w400, c.body, h: 1.45),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? c.raised : c.ink,
        contentTextStyle: t(14, FontWeight.w500, isDark ? c.headline : c.onInk),
        actionTextColor: isDark ? c.link : Color.lerp(c.accent, Colors.white, 0.5),
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: r12),
        elevation: 6,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.headline,
        unselectedLabelColor: c.muted,
        indicatorColor: c.accent,
        dividerColor: c.border,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface,
          selectedBackgroundColor: c.ink,
          selectedForegroundColor: c.onInk,
          foregroundColor: c.body,
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: r12),
        ),
      ),
      badgeTheme: BadgeThemeData(backgroundColor: c.danger, textColor: Colors.white, textStyle: t(11, FontWeight.w700, Colors.white)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(NrRadius.md)),
        textStyle: t(12, FontWeight.w500, c.onInk),
      ),
    );
  }
}
