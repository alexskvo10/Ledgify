import 'package:flutter/material.dart';

/// Semantic colours for one brightness.
///
/// Widgets never pick raw hex values: they ask for a *role* (surface, text,
/// accent…) via `context.palette`, so light and dark themes both work.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.brightness,
    required this.bg,
    required this.glow,
    required this.surface,
    required this.surfaceHover,
    required this.raised,
    required this.sunken,
    required this.stroke,
    required this.strokeStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentText,
    required this.accentFill,
    required this.danger,
    required this.warning,
    required this.info,
    required this.scrim,
    required this.shadow,
  });

  final Brightness brightness;

  /// Window background and its soft corner glow.
  final Color bg;
  final LinearGradient glow;

  /// Cards and rows.
  final Color surface;
  final Color surfaceHover;

  /// Sheets, dialogs, menus — floats above cards.
  final Color raised;

  /// Inputs and inactive chips — sits below the card level.
  final Color sunken;

  final Color stroke;
  final Color strokeStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Brand green for fills; [accentText] is the same hue tuned for text
  /// contrast on the current background.
  final Color accent;
  final Color accentText;

  /// Background for filled buttons with white labels (≥ 4.4:1 contrast —
  /// the bright brand green is only 2.2:1 against white).
  final Color accentFill;

  final Color danger;
  final Color warning;
  final Color info;

  final Color scrim;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  /// Tinted background for a coloured element (selected chip, tag, icon tile).
  Color tint(Color c, [double strength = 1]) =>
      c.withValues(alpha: (isDark ? 0.16 : 0.12) * strength);

  static const dark = Palette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F13),
    glow: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10201C), Color(0xFF0E0F13), Color(0xFF11151E)],
    ),
    surface: Color(0xFF17181E),
    surfaceHover: Color(0xFF1D1F27),
    raised: Color(0xFF1C1D24),
    sunken: Color(0xFF23252E),
    stroke: Color(0xFF2A2C36),
    strokeStrong: Color(0xFF3A3D4A),
    textPrimary: Color(0xFFF5F6FA),
    textSecondary: Color(0xFFA0A3B1),
    textTertiary: Color(0xFF737786),
    accent: Color(0xFF34C759),
    accentText: Color(0xFF3DD266),
    accentFill: Color(0xFF1B8A3B),
    danger: Color(0xFFFF453A),
    warning: Color(0xFFFF9F0A),
    info: Color(0xFF0A84FF),
    scrim: Color(0x99000000),
    shadow: Color(0x66000000),
  );

  static const light = Palette(
    brightness: Brightness.light,
    bg: Color(0xFFF2F2F7),
    glow: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEAF6EE), Color(0xFFF2F2F7), Color(0xFFF3F1F8)],
    ),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF8F8FB),
    raised: Color(0xFFFFFFFF),
    sunken: Color(0xFFEDEDF2),
    stroke: Color(0xFFE0E0E6),
    strokeStrong: Color(0xFFC7C7CE),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF5E5E63),
    textTertiary: Color(0xFF6E6E78),
    accent: Color(0xFF34C759),
    accentText: Color(0xFF1B7F37),
    accentFill: Color(0xFF1B8A3B),
    danger: Color(0xFFD70015),
    warning: Color(0xFFB35600),
    info: Color(0xFF0066CC),
    scrim: Color(0x66000000),
    shadow: Color(0x1F000000),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}
