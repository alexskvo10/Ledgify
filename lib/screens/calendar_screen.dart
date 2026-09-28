import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/settings_provider.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/budget.dart';
import '../widgets/service_avatar.dart';
import '../widgets/sub_actions.dart';
import '../widgets/sub_tile.dart';
import '../widgets/ui.dart';

/// Month at a glance: total, mood, budget, reminders, the grid of charges and
/// the list of this month's payments (beside the grid on wide windows).
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubsProvider>();
    final month = subs.visibleMonth;
    final payments = subs.paymentsInMonth(month);

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= Layout.wide;
        final calendar = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(month: month, payments: payments),
            if (subs.isCurrentMonth && subs.dueReminders.isNotEmpty) ...[
              const SizedBox(height: Space.l),
              _Reminders(items: subs.dueReminders),
            ],
            const SizedBox(height: Space.l),
            _Grid(month: month, payments: payments),
          ],
        );
        final list = _MonthList(payments: payments);

        if (wide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Space.xxl,
                        Space.xs,
                        Space.l,
                        110,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: calendar,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 380,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Space.s,
                        Space.xs,
                        Space.xxl,
                        110,
                      ),
                      child: list,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.l, 110),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.maxContent),
              child: Column(children: [calendar, list]),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.month, required this.payments});
  final DateTime month;
  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.read<SubsProvider>();
    final budget = context.watch<SettingsProvider>().budget;
    final cur = subs.baseCurrency;
    final total = payments.fold(0.0, (sum, x) => sum + x.baseAmount);
    final average = subs.yearAverageAround(month);
    final mood = subs.moodFor(total, average);
    final moodColor = switch (mood) {
      MonthMood.heavy => p.warning,
      MonthMood.quiet => p.textSecondary,
      _ => p.accentText,
    };

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: '${s.prevMonth}  (←)',
              onPressed: subs.prevMonth,
            ),
            Expanded(
              child: Text(
                s.monthYear(month),
                textAlign: TextAlign.center,
                style: TextStyles.headline.copyWith(fontSize: 18),
              ),
            ),
            AppIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: '${s.nextMonth}  (→)',
              onPressed: subs.nextMonth,
            ),
          ],
        ),
        const SizedBox(height: Space.s),
        // Count-up from the previous month's total to this one.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: total),
          duration: Motion.counter,
          curve: Motion.enter,
          builder: (_, v, _) => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(s.money(v, cur), style: TextStyles.display),
          ),
        ),
        const SizedBox(height: Space.s),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            Tooltip(
              message: s.moodHint(s.money(average, cur)),
              child: _Pill(text: s.mood(mood), color: moodColor, filled: true),
            ),
            if (payments.isNotEmpty)
              _Pill(
                text: s.paymentsCount(payments.length),
                color: p.textSecondary,
              ),
            if (!subs.isCurrentMonth)
              ActionChip(
                avatar: Icon(
                  Icons.today_rounded,
                  size: 16,
                  color: p.accentText,
                ),
                label: Text(s.backToToday),
                labelStyle: TextStyles.subhead.copyWith(
                  color: p.accentText,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: p.accent.withValues(alpha: 0.5)),
                backgroundColor: p.tint(p.accent),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                onPressed: subs.goToToday,
              ),
          ],
        ),
        if (budget > 0) ...[
          const SizedBox(height: Space.l),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: BudgetBar(spent: total, budget: budget, currency: cur),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.filled = false});
  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: Motion.slow,
      curve: Motion.enter,
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? p.tint(color) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: filled ? 0.35 : 0.3)),
      ),
      child: AnimatedDefaultTextStyle(
        duration: Motion.slow,
        style: TextStyles.subhead.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
        child: Text(text),
      ),
    );
  }
}

class _Reminders extends StatelessWidget {
  const _Reminders({required this.items});
  final List<Payment> items;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final today = context.read<SubsProvider>().today;
    return AppCard(
      color: p.tint(p.warning, 0.6),
      borderColor: p.warning.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.l, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 18,
                color: p.warning,
              ),
              const SizedBox(width: Space.s),
              Text(
                s.comingUp,
                style: TextStyles.subhead.copyWith(
                  color: p.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          for (final r in items)
            InkWell(
              borderRadius: BorderRadius.circular(Radii.s),
              onTap: () => openSubDetail(context, r.sub),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                // Two lines instead of one row: survives narrow phones and
                // large system font sizes without clipping the amount.
                child: Row(
                  children: [
                    ServiceAvatar.of(r.sub, size: 32),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.sub.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.callout.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${s.relativeDay(r.date, today)} · ${s.money(r.sub.amount, r.sub.currency)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.footnote.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.month, required this.payments});
  final DateTime month;
  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday - 1;

    final byDay = <int, List<Payment>>{};
    for (final x in payments) {
      byDay.putIfAbsent(x.date.day, () => []).add(x);
    }
    final dayTotals = {
      for (final e in byDay.entries)
        e.key: e.value.fold(0.0, (sum, x) => sum + x.baseAmount),
    };
    final maxDay = dayTotals.values.fold(0.0, math.max);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 6.0;
          final cellW = (c.maxWidth - gap * 6) / 7;
          final cellH = cellW < 56 ? 60.0 : 76.0;
          return Column(
            children: [
              Row(
                children: [
                  for (final (i, d) in s.weekdays.indexed)
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyles.caption.copyWith(
                            color: i >= 5 ? p.textTertiary : p.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.s),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leading + daysInMonth,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  mainAxisExtent: cellH,
                ),
                itemBuilder: (context, i) {
                  if (i < leading) return const SizedBox.shrink();
                  final day = i - leading + 1;
                  final total = dayTotals[day] ?? 0;
                  return _DayCell(
                    date: DateTime(month.year, month.month, day),
                    payments: byDay[day] ?? const [],
                    total: total,
                    intensity: maxDay > 0 ? total / maxDay : 0,
                    width: cellW,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.payments,
    required this.total,
    required this.intensity,
    required this.width,
  });

  final DateTime date;
  final List<Payment> payments;
  final double total;

  /// 0..1 share of the busiest day — drives the heat tint.
  final double intensity;
  final double width;

  void _open(BuildContext context) {
    if (payments.isEmpty) return;
    if (payments.length == 1) {
      openSubDetail(context, payments.first.sub);
      return;
    }
    final s = S.of(context);
    final cur = context.read<SubsProvider>().baseCurrency;
    showAppSheet(
      context,
      (sheet) => SheetFrame(
        title: s.weekdayDate(date),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${s.paymentsCount(payments.length)} · ${s.money(total, cur)}',
              style: TextStyles.callout.copyWith(
                color: sheet.palette.textSecondary,
              ),
            ),
            const SizedBox(height: Space.m),
            for (final x in payments) ...[
              SubTile(
                sub: x.sub,
                date: x.date,
                compact: true,
                onTap: () {
                  Navigator.pop(sheet);
                  openSubDetail(context, x.sub);
                },
              ),
              const SizedBox(height: Space.s),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isToday = date == context.read<SubsProvider>().today;
    final has = payments.isNotEmpty;

    return _HoverBuilder(
      builder: (context, hover) {
        // Heat tint by share of the busiest day; the mouse brightens the
        // cell, outlines it and (for days with charges) lifts it slightly.
        final bg = has
            ? Color.alphaBlend(
                p.accent.withValues(
                  alpha: 0.08 + 0.22 * intensity + (hover ? 0.1 : 0),
                ),
                p.surface,
              )
            : (hover
                  ? p.surface
                  : p.surface.withValues(alpha: p.isDark ? 0.45 : 0.6));
        final border = isToday
            ? BorderSide(color: p.accent, width: 1.6)
            : BorderSide(
                color: hover
                    ? (has ? p.accent.withValues(alpha: 0.6) : p.strokeStrong)
                    : (has
                          ? p.accent.withValues(alpha: 0.18)
                          : Colors.transparent),
              );
        return _cell(context, bg, border, hover && has);
      },
    );
  }

  Widget _cell(BuildContext context, Color bg, BorderSide border, bool lift) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.read<SubsProvider>();
    final today = subs.today;
    final isToday = date == today;
    final isPast = date.isBefore(today);
    final has = payments.isNotEmpty;

    final avatar = width < 44 ? 12.0 : (width < 52 ? 14.0 : 16.0);
    // 5 px padding + up to 1.6 px border on each side.
    final slots = math.max(1, ((width - 14) / (avatar + 2)).floor());
    final shown = payments.length > slots ? slots - 1 : payments.length;
    final extra = payments.length - shown;

    return Semantics(
      button: has,
      label:
          '${s.longDate(date)}${has ? ', ${s.paymentsCount(payments.length)}, ${s.money(total, subs.baseCurrency)}' : ''}',
      excludeSemantics: true,
      child: _MaybeTooltip(
        message: payments
            .map(
              (x) => '${x.sub.name}  ${s.money(x.sub.amount, x.sub.currency)}',
            )
            .join('\n'),
        child: AnimatedScale(
          scale: lift ? 1.05 : 1,
          duration: Motion.fast,
          curve: Motion.enter,
          child: AnimatedContainer(
            duration: Motion.fast,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.m - 2),
              border: Border.fromBorderSide(border),
              boxShadow: lift
                  ? [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(Radii.m - 2),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: has ? () => _open(context) : null,
                mouseCursor: has ? SystemMouseCursors.click : MouseCursor.defer,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyles.footnote.copyWith(
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isToday
                              ? p.accentText
                              : (isPast ? p.textTertiary : p.textSecondary),
                        ),
                      ),
                      const Spacer(),
                      if (has) ...[
                        Row(
                          children: [
                            for (final x in payments.take(shown)) ...[
                              ServiceAvatar.of(x.sub, size: avatar),
                              const SizedBox(width: 2),
                            ],
                            if (extra > 0)
                              Text(
                                '+$extra',
                                style: TextStyles.micro.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                          ],
                        ),
                        if (width >= 40) ...[
                          const SizedBox(height: 2),
                          Text(
                            s.moneyTiny(total, subs.baseCurrency),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyles.micro.copyWith(
                              color: p.isDark ? p.textPrimary : p.accentText,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tracks whether the mouse is over [builder]'s widget.
class _HoverBuilder extends StatefulWidget {
  const _HoverBuilder({required this.builder});
  final Widget Function(BuildContext context, bool hover) builder;

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: widget.builder(context, _hover),
  );
}

class _MaybeTooltip extends StatelessWidget {
  const _MaybeTooltip({required this.message, required this.child});
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      message.isEmpty ? child : Tooltip(message: message, child: child);
}

class _MonthList extends StatelessWidget {
  const _MonthList({required this.payments});
  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(s.monthPayments),
        if (payments.isEmpty)
          AppCard(
            child: Text(
              s.noMonthPayments,
              textAlign: TextAlign.center,
              style: TextStyles.callout.copyWith(color: p.textSecondary),
            ),
          )
        else
          for (final x in payments) ...[
            SubTile(
              sub: x.sub,
              date: x.date,
              compact: true,
              onTap: () => openSubDetail(context, x.sub),
            ),
            const SizedBox(height: Space.s),
          ],
      ],
    );
  }
}
