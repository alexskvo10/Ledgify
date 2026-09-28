import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../state/settings_provider.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/budget.dart';
import '../widgets/empty_state.dart';
import '../widgets/service_avatar.dart';
import '../widgets/sub_actions.dart';
import '../widgets/ui.dart';

/// Forecasts, budget, monthly trend, category split and the priciest services.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _months = 6;
  SubCategory? _highlight;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final subs = context.watch<SubsProvider>();
    final cur = subs.baseCurrency;
    final trends = subs.lastMonths(_months);
    final hasHistory = trends.any((t) => t.total > 0);

    if (subs.recurring.isEmpty && !hasHistory) {
      return EmptyState(
        icon: Icons.donut_large_rounded,
        title: s.statsEmpty,
        body: s.statsEmptyBody,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.maxContent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Space.xs),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: s.perMonth,
                      value: s.money(subs.monthlyForecast, cur, whole: true),
                      icon: Icons.calendar_view_month_rounded,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: _Metric(
                      label: s.perYear,
                      value: s.money(subs.yearlyForecast, cur, whole: true),
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: _Metric(
                      label: s.activeCount,
                      value: '${subs.recurring.length}',
                      icon: Icons.layers_rounded,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.s, left: Space.xs),
                child: Text(
                  s.forecastHint,
                  style: TextStyles.footnote.copyWith(
                    color: context.palette.textTertiary,
                  ),
                ),
              ),
              SectionLabel(s.budget),
              const _BudgetCard(),
              SectionLabel(
                s.trends,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final n in [6, 12]) ...[
                      const SizedBox(width: Space.xs),
                      AppChip(
                        label: s.monthsN(n),
                        selected: _months == n,
                        onTap: () => setState(() => _months = n),
                      ),
                    ],
                  ],
                ),
              ),
              _TrendCard(trends: trends, currency: cur),
              if (subs.spendByCategory.isNotEmpty) ...[
                SectionLabel(s.byCategory),
                _CategoryCard(
                  data: subs.spendByCategory,
                  currency: cur,
                  highlight: _highlight,
                  onHighlight: (c) =>
                      setState(() => _highlight = _highlight == c ? null : c),
                ),
              ],
              if (subs.byMonthlyCost.isNotEmpty) ...[
                SectionLabel(s.mostExpensive),
                _TopList(items: subs.byMonthlyCost.take(5).toList()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(Space.m + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: p.accentText),
          const SizedBox(height: Space.s),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyles.title2.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyles.footnote.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.watch<SubsProvider>();
    final budget = context.watch<SettingsProvider>().budget;
    final cur = subs.baseCurrency;
    final spent = subs.totalFor(subs.today);

    return AppCard(
      child: budget <= 0
          ? Row(
              children: [
                Icon(Icons.savings_outlined, color: p.textSecondary),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(
                    s.budgetEmpty,
                    style: TextStyles.callout.copyWith(color: p.textSecondary),
                  ),
                ),
                const SizedBox(width: Space.s),
                TextButton(
                  onPressed: () => showBudgetDialog(context),
                  child: Text(s.setBudget),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.thisMonth, style: TextStyles.headline),
                    ),
                    TextButton(
                      onPressed: () => showBudgetDialog(context),
                      child: Text(s.changeBudget),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                BudgetBar(spent: spent, budget: budget, currency: cur),
              ],
            ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trends, required this.currency});
  final List<MonthlyTotal> trends;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final maxY = trends.fold(0.0, (m, t) => t.total > m ? t.total : m);
    final top = maxY <= 0 ? 1.0 : maxY * 1.15;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.s, Space.xl, Space.l, Space.m),
      child: SizedBox(
        height: 190,
        child: BarChart(
          BarChartData(
            maxY: top,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: top / 4,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: p.stroke, strokeWidth: 1, dashArray: [4, 4]),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => p.isDark ? p.sunken : p.textPrimary,
                tooltipBorderRadius: BorderRadius.circular(Radii.s),
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${s.monthYear(trends[group.x].month)}\n',
                  TextStyles.footnote.copyWith(
                    color: p.isDark ? p.textSecondary : Colors.white70,
                  ),
                  children: [
                    TextSpan(
                      text: s.money(rod.toY, currency),
                      style: TextStyles.callout.copyWith(
                        color: p.isDark ? p.textPrimary : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= trends.length) return const SizedBox();
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        s.monthShort(trends[i].month),
                        style: TextStyles.micro.copyWith(
                          color: i == trends.length - 1
                              ? p.textPrimary
                              : p.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (final (i, t) in trends.indexed)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: t.total,
                      width: trends.length > 6 ? 14 : 22,
                      color: i == trends.length - 1
                          ? p.accent
                          : p.accent.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          duration: Motion.slow,
          curve: Motion.enter,
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.data,
    required this.currency,
    required this.highlight,
    required this.onHighlight,
  });

  final Map<SubCategory, double> data;
  final String currency;
  final SubCategory? highlight;
  final ValueChanged<SubCategory> onHighlight;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (sum, e) => sum + e.value);
    final focus = highlight != null && data.containsKey(highlight)
        ? highlight
        : null;

    final chart = SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 64,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, resp) {
                  final i = resp?.touchedSection?.touchedSectionIndex ?? -1;
                  if (event is FlTapUpEvent && i >= 0 && i < entries.length) {
                    onHighlight(entries[i].key);
                  }
                },
              ),
              sections: [
                for (final e in entries)
                  PieChartSectionData(
                    value: e.value,
                    color: focus == null || focus == e.key
                        ? e.key.color
                        : e.key.color.withValues(alpha: 0.25),
                    radius: focus == e.key ? 30 : 24,
                    showTitle: false,
                  ),
              ],
            ),
            duration: Motion.base,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                focus == null ? s.perMonth : s.category(focus),
                style: TextStyles.footnote.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                s.money(
                  focus == null ? total : data[focus]!,
                  currency,
                  whole: true,
                ),
                style: TextStyles.title2.copyWith(
                  color: focus == null ? p.textPrimary : focus.color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final legend = Column(
      children: [
        for (final e in entries)
          InkWell(
            borderRadius: BorderRadius.circular(Radii.s),
            onTap: () => onHighlight(e.key),
            child: AnimatedContainer(
              duration: Motion.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: Space.s,
                vertical: Space.s,
              ),
              decoration: BoxDecoration(
                color: focus == e.key ? p.tint(e.key.color) : null,
                borderRadius: BorderRadius.circular(Radii.s),
              ),
              child: Row(
                children: [
                  Dot(e.key.color, size: 10),
                  const SizedBox(width: Space.s + 2),
                  Expanded(
                    child: Text(
                      s.category(e.key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.callout,
                    ),
                  ),
                  Text(
                    s.money(e.value, currency, whole: true),
                    style: TextStyles.callout.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${(total == 0 ? 0 : e.value / total * 100).round()}%',
                      textAlign: TextAlign.end,
                      style: TextStyles.footnote.copyWith(
                        color: p.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return AppCard(
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 560
            ? Row(
                children: [
                  chart,
                  const SizedBox(width: Space.xxl),
                  Expanded(child: legend),
                ],
              )
            : Column(
                children: [
                  chart,
                  const SizedBox(height: Space.l),
                  legend,
                ],
              ),
      ),
    );
  }
}

class _TopList extends StatelessWidget {
  const _TopList({required this.items});
  final List<Subscription> items;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.read<SubsProvider>();
    final max = subs.toBase(items.first, items.first.monthlyEquivalent);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Column(
        children: [
          for (final sub in items)
            InkWell(
              onTap: () => openSubDetail(context, sub),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.l,
                  vertical: Space.s,
                ),
                child: Row(
                  children: [
                    ServiceAvatar.of(sub, size: 32),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.callout.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: LinearProgressIndicator(
                              value: max <= 0
                                  ? 0
                                  : subs.toBase(sub, sub.monthlyEquivalent) /
                                        max,
                              minHeight: 4,
                              color: sub.category.color,
                              backgroundColor: p.sunken,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Space.l),
                    Text(
                      '${s.money(subs.toBase(sub, sub.monthlyEquivalent), subs.baseCurrency, whole: true)}${s.perMonthShort}',
                      style: TextStyles.callout.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
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
