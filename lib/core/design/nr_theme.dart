import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nr_tokens.dart';
import 'nr_typography.dart';

/// Tema Material 3 construido solo con [NrColors] (claro y oscuro).
abstract final class NrTheme {
  static ThemeData light(Color accent) => _build(NrColors.light(accent), Brightness.light);
  static ThemeData dark(Color accent) => _build(NrColors.dark(accent), Brightness.dark);

  static ThemeData _build(NrColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const family = NrText.family;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: Colors.white,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
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

    final r10 = BorderRadius.circular(NrRadius.lg);
    final r12 = BorderRadius.circular(NrRadius.xl);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: family,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.border,
      extensions: [c],
      textTheme: TextTheme(
        headlineMedium: t(22, FontWeight.w700, c.headline, ls: -0.5),
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
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: c.canvas,
        foregroundColor: c.headline,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: t(17, FontWeight.w600, c.headline, ls: -0.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: r12, side: BorderSide(color: c.border)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: t(15, FontWeight.w400, c.muted),
        labelStyle: t(14, FontWeight.w500, c.secondary),
        floatingLabelStyle: t(13, FontWeight.w500, c.accent),
        border: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: c.borderStrong)),
        enabledBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: c.borderStrong)),
        focusedBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: c.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: r10, borderSide: BorderSide(color: c.danger)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          disabledBackgroundColor: c.raised,
          disabledForegroundColor: c.muted,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: r10),
          textStyle: t(15, FontWeight.w500, c.onInk),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.headline,
          backgroundColor: c.surface,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: r10),
          textStyle: t(15, FontWeight.w500, c.headline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.link, textStyle: t(14, FontWeight.w600, c.link)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.ink,
        foregroundColor: c.onInk,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.xxl)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        side: BorderSide(color: c.border),
        labelStyle: t(13, FontWeight.w500, c.body),
        secondaryLabelStyle: t(13, FontWeight.w500, c.onInk),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.pill)),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.secondary,
        titleTextStyle: t(15, FontWeight.w500, c.headline),
        subtitleTextStyle: t(13, FontWeight.w400, c.secondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : c.surface),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.borderStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.raised),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NrRadius.xxl))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NrRadius.xxl)),
        titleTextStyle: t(18, FontWeight.w600, c.headline, ls: -0.3),
        contentTextStyle: t(15, FontWeight.w400, c.body, h: 1.45),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        contentTextStyle: t(14, FontWeight.w500, c.onInk),
        shape: RoundedRectangleBorder(borderRadius: r10),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.headline,
        unselectedLabelColor: c.muted,
        indicatorColor: c.headline,
        dividerColor: c.border,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.accentSoft,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => t(11, s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
              s.contains(WidgetState.selected) ? c.headline : c.muted),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 24, color: s.contains(WidgetState.selected) ? c.accent : c.muted),
        ),
      ),
    );
  }
}
