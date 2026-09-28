import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

/// Builds Material [ThemeData] from the design tokens, so stock widgets
/// (dialogs, menus, snackbars, date picker, switches) match the custom ones.
abstract final class AppTheme {
  static ThemeData get dark => _build(Palette.dark);
  static ThemeData get light => _build(Palette.light);

  static ThemeData _build(Palette p) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: p.accent,
          brightness: p.brightness,
        ).copyWith(
          primary: p.accentFill,
          onPrimary: Colors.white,
          primaryContainer: p.accentFill,
          onPrimaryContainer: Colors.white,
          secondary: p.accent,
          error: p.danger,
          surface: p.raised,
          onSurface: p.textPrimary,
          onSurfaceVariant: p.textSecondary,
          outline: p.strokeStrong,
          outlineVariant: p.stroke,
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: TextStyles.family,
      fontFamilyFallback: TextStyles.fallback,
    );

    return base.copyWith(
      extensions: [p],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.raised,
      dividerColor: p.stroke,
      splashFactory: InkRipple.splashFactory,
      focusColor: p.accent.withValues(alpha: 0.18),
      hoverColor: p.textPrimary.withValues(alpha: 0.04),
      textTheme: base.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      dividerTheme: DividerThemeData(color: p.stroke, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: p.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
        titleTextStyle: TextStyles.title2.copyWith(color: p.textPrimary),
        contentTextStyle: TextStyles.body.copyWith(color: p.textSecondary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.m),
          side: BorderSide(color: p.stroke),
        ),
        textStyle: TextStyles.callout.copyWith(color: p.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? const Color(0xFF2A2C36) : p.textPrimary,
        contentTextStyle: TextStyles.callout.copyWith(color: Colors.white),
        actionTextColor: p.isDark ? p.accentText : p.accent,
        shape: RoundedRectangleBorder(borderRadius: Radii.control),
        width: 440,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.isDark ? p.sunken : p.textPrimary,
          borderRadius: BorderRadius.circular(Radii.s),
        ),
        textStyle: TextStyles.footnote.copyWith(
          color: p.isDark ? p.textPrimary : Colors.white,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Colors.white : p.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.sunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.strokeStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.accent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.raised,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.raised,
        headerForegroundColor: p.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          textStyle: TextStyles.callout.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: Radii.control),
          minimumSize: const Size(64, Layout.hit),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.sunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.l,
          vertical: 14,
        ),
        labelStyle: TextStyles.callout.copyWith(color: p.textSecondary),
        floatingLabelStyle: TextStyles.callout.copyWith(color: p.accentText),
        hintStyle: TextStyles.body.copyWith(color: p.textTertiary),
        errorStyle: TextStyles.footnote.copyWith(color: p.danger),
        border: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: p.stroke.withValues(alpha: 0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.control,
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(p.strokeStrong),
        radius: const Radius.circular(Radii.pill),
        thickness: const WidgetStatePropertyAll(6),
      ),
    );
  }
}
