import 'package:flutter/material.dart';

/// Design tokens: the fixed numbers every screen is built from.
///
/// Why tokens: when every padding, radius and duration comes from this file,
/// the app feels consistent and a design tweak is a one-line change.
/// See docs/DESIGN_SYSTEM.md for the reasoning behind each value.

/// 4-point spacing scale.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Horizontal page gutter.
  static const double gutter = 20;
}

abstract final class Radii {
  static const double xs = 6; // tags
  static const double s = 10; // chips, small inputs
  static const double m = 14; // inputs, buttons, day cells
  static const double l = 20; // cards
  static const double xl = 28; // sheets, dialogs
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(l);
  static BorderRadius get control => BorderRadius.circular(m);
}

/// Motion: durations and curves. (Named `Motion` because Flutter already
/// ships a `Durations` class.)
abstract final class Motion {
  static const fast = Duration(milliseconds: 150); // hover, press
  static const base = Duration(milliseconds: 220); // selection changes
  static const slow = Duration(milliseconds: 350); // screen switches
  static const counter = Duration(milliseconds: 550); // big number count-up

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
}

/// Layout breakpoints and content widths.
abstract final class Layout {
  /// Content column never grows wider than this — long lines are hard to read.
  static const double maxContent = 760;

  /// From this width the calendar tab shows the month list on the right.
  static const double wide = 1000;

  static const double sheetMaxWidth = 560;
  static const double dialogWidth = 380;

  /// Minimum comfortable hit target.
  static const double hit = 40;
}

/// Type scale. Tabular figures keep money columns aligned.
///
/// Every style carries the font family itself: component themes (dialogs,
/// buttons, snackbars) *replace* the inherited text style instead of merging,
/// so a style without a family would fall back to the engine default.
abstract final class TextStyles {
  static const _tab = [FontFeature.tabularFigures()];
  static const family = 'Segoe UI';

  /// Colour emoji for service icons on Windows; Android uses its own fonts.
  static const fallback = ['Segoe UI Emoji', 'Segoe UI Symbol'];

  static const display = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.1,
    fontFeatures: _tab,
  );
  static const title1 = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const title2 = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const headline = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const body = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 15,
    height: 1.4,
  );
  static const callout = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );
  static const subhead = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
  static const footnote = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 12,
    height: 1.3,
  );
  static const caption = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,

    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.2,
  );
  static const micro = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  /// Money inside rows and cards.
  static const amount = TextStyle(
    fontFamily: family,
    fontFamilyFallback: fallback,

    fontSize: 15,
    fontWeight: FontWeight.w700,
    fontFeatures: _tab,
  );
}
