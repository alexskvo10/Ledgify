import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';

/// Core building blocks of the design system (docs/DESIGN_SYSTEM.md).

/// Surface card: 1px stroke, rounded, optional tap with hover/press feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.l),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(color: borderColor ?? p.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: p.surfaceHover,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Uppercase label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.xxl,
        Space.xs,
        Space.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyles.caption.copyWith(
                color: context.palette.textTertiary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Selectable pill used for filters and single-choice pickers.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Accent for the selected state (defaults to brand green).
  final Color? color;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = color ?? p.accent;
    final fg = selected
        ? (color == null ? p.accentText : p.textPrimary)
        : p.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.tint(c, 1.2) : p.sunken,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? c : Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 6)],
                  Text(
                    label,
                    style: TextStyles.subhead.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round 40×40 icon button with tooltip (the tooltip doubles as a11y label).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface.withValues(alpha: p.isDark ? 0.7 : 0.9),
        shape: CircleBorder(side: BorderSide(color: p.stroke)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: Layout.hit,
            child: Icon(icon, size: 20, color: color ?? p.textSecondary),
          ),
        ),
      ),
    );
  }
}

enum ButtonKind { primary, secondary, danger }

/// Full-height (48) text button in three flavours.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonKind.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonKind kind;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, fg) = switch (kind) {
      ButtonKind.primary => (p.accentFill, Colors.white),
      ButtonKind.secondary => (p.sunken, p.textPrimary),
      ButtonKind.danger => (p.tint(p.danger), p.danger),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: Space.s),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.callout.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: Radii.control,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xl),
              child: Center(widthFactor: expand ? null : 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

Color statusColor(Palette p, SubStatus s) => switch (s) {
  SubStatus.active => p.accentText,
  SubStatus.trial => p.info,
  SubStatus.canceled => p.danger,
  SubStatus.archived => p.textTertiary,
};

/// Small coloured status label.
class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});
  final SubStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = statusColor(p, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: p.tint(c),
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
      child: Text(
        S.of(context).status(status),
        style: TextStyles.micro.copyWith(color: c),
      ),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Opens a bottom sheet in the app style: rounded top, grabber, keyboard
/// aware, centred with a max width on desktop.
///
/// Pass `enableDrag: false` for forms: a drag-dismiss would skip the
/// "discard changes?" check.
Future<T?> showAppSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    enableDrag: enableDrag,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: context.palette.scrim,
    constraints: const BoxConstraints(maxWidth: Layout.sheetMaxWidth),
    builder: builder,
  );
}

/// Frame for sheet content: grabber, title row, scrolling body, sticky footer.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.footer,
    this.onClose,
  });

  final String title;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.xl),
          ),
          border: Border.all(color: p.stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Space.s),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.strokeStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.m,
                Space.m,
                Space.s,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: TextStyles.title2)),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    tooltip: S.of(context).close,
                    onPressed: onClose ?? () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Space.xl,
                  Space.s,
                  Space.xl,
                  Space.xl,
                ),
                child: child,
              ),
            ),
            if (footer != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  Space.xl,
                  Space.m,
                  Space.xl,
                  Space.m + media.padding.bottom,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.stroke)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Two-button confirmation dialog. Returns true when confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool danger = false,
}) async {
  final s = S.of(context);
  final p = context.palette;
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: p.scrim,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.dialogWidth),
              child: Text(message),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: Text(s.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: danger
              ? TextButton.styleFrom(foregroundColor: p.danger)
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Shows a floating toast, replacing the current one.
void toast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) => toastOn(
  ScaffoldMessenger.of(context),
  message,
  actionLabel: actionLabel,
  onAction: onAction,
);

/// Same as [toast] for callers that must look the messenger up *before* an
/// await — e.g. when the widget that started the action is about to vanish
/// (a deleted row).
void toastOn(
  ScaffoldMessengerState m,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: onAction != null ? 5 : 3),
      action: onAction != null && actionLabel != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}

/// The Ledgify logo mark: a green tile with a ledger "L" and a coin dot.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3DDC6A), Color(0xFF1E9E44)],
          ),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: CustomPaint(painter: _MarkPainter()),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(w * 0.34, w * 0.26)
      ..lineTo(w * 0.34, w * 0.72)
      ..lineTo(w * 0.70, w * 0.72);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(w * 0.68, w * 0.36),
      w * 0.09,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
