import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/demo_data.dart';
import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/sub_actions.dart';
import '../widgets/sub_tile.dart';
import '../widgets/ui.dart';

enum _Sort { next, amount, name, category }

/// All subscriptions with search, a status filter and sorting.
/// The top-bar search icon (Ctrl+F) lands here with the field focused.
class ListScreen extends StatefulWidget {
  const ListScreen({super.key, required this.searchFocus});
  final FocusNode searchFocus;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _query = TextEditingController();

  /// `null` = everything except archived.
  SubStatus? _status;
  _Sort _sort = _Sort.next;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Subscription> _apply(SubsProvider subs, S s) {
    final q = _query.text.trim().toLowerCase();
    final today = subs.today;
    final list = subs.all.where((x) {
      final statusOk = _status == null
          ? x.status != SubStatus.archived
          : x.status == _status;
      if (!statusOk) return false;
      if (q.isEmpty) return true;
      return x.name.toLowerCase().contains(q) ||
          s.category(x.category).toLowerCase().contains(q) ||
          x.notes.toLowerCase().contains(q);
    }).toList();

    int byName(Subscription a, Subscription b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (_sort) {
      case _Sort.next:
        final next = {for (final x in list) x.id: x.nextPaymentFrom(today)};
        list.sort((a, b) {
          final na = next[a.id], nb = next[b.id];
          if (na == null && nb == null) return byName(a, b);
          if (na == null) return 1;
          if (nb == null) return -1;
          final c = na.compareTo(nb);
          return c != 0 ? c : byName(a, b);
        });
      case _Sort.amount:
        list.sort((a, b) {
          // One-time payments have no monthly cost; rank them by amount.
          double v(Subscription x) => subs.toBase(
            x,
            x.cycle == BillingCycle.oneTime ? x.amount : x.monthlyEquivalent,
          );
          final c = v(b).compareTo(v(a));
          return c != 0 ? c : byName(a, b);
        });
      case _Sort.name:
        list.sort(byName);
      case _Sort.category:
        list.sort((a, b) {
          final c = a.category.index.compareTo(b.category.index);
          return c != 0 ? c : byName(a, b);
        });
    }
    return list;
  }

  String _sortLabel(S s, _Sort v) => switch (v) {
    _Sort.next => s.sortNext,
    _Sort.amount => s.sortAmount,
    _Sort.name => s.sortName,
    _Sort.category => s.sortCategory,
  };

  void _reset() => setState(() {
    _query.clear();
    _status = null;
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.watch<SubsProvider>();

    if (subs.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: s.emptyTitle,
        body: s.emptyBody,
        actions: [
          AppButton(
            label: s.tryDemo,
            kind: ButtonKind.secondary,
            onPressed: () => subs.upsertAll(buildDemoData(subs.today)),
          ),
        ],
      );
    }

    final items = _apply(subs, s);
    final monthly = items
        .where((x) => x.status.isRecurring)
        .fold(0.0, (sum, x) => sum + subs.toBase(x, x.monthlyEquivalent));
    final filtered = _query.text.isNotEmpty || _status != null;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          focusNode: widget.searchFocus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.searchHint,
            prefixIcon: Icon(Icons.search_rounded, color: p.textTertiary),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: s.remove,
                    icon: Icon(Icons.close_rounded, color: p.textTertiary),
                    onPressed: () => setState(_query.clear),
                  ),
            fillColor: p.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: Radii.control,
              borderSide: BorderSide(color: p.stroke),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.m),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final st in <SubStatus?>[null, ...SubStatus.values]) ...[
                AppChip(
                  label: st == null ? s.filterAll : s.statusFilter(st),
                  selected: _status == st,
                  color: st == null ? null : statusColor(p, st),
                  onTap: () => setState(() => _status = st),
                ),
                const SizedBox(width: Space.s),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(
              child: Text(
                items.isEmpty
                    ? ''
                    : '${s.subscriptions(items.length)}'
                          '${monthly > 0 ? ' · ${s.money(monthly, subs.baseCurrency, whole: true)}${s.perMonthShort}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyles.subhead.copyWith(color: p.textSecondary),
              ),
            ),
            PopupMenuButton<_Sort>(
              tooltip: s.sortBy,
              initialValue: _sort,
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => [
                for (final v in _Sort.values)
                  CheckedPopupMenuItem(
                    value: v,
                    checked: v == _sort,
                    child: Text(_sortLabel(s, v)),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.s,
                  vertical: Space.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 18,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: Space.xs),
                    Text(
                      _sortLabel(s, _sort),
                      style: TextStyles.subhead.copyWith(
                        color: p.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.maxContent),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.l, Space.xs, Space.l, 0),
              sliver: SliverToBoxAdapter(child: header),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: s.nothingFound,
                  body: s.nothingFoundBody,
                  actions: [
                    if (filtered)
                      AppButton(
                        label: s.resetFilters,
                        kind: ButtonKind.secondary,
                        onPressed: _reset,
                      ),
                  ],
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, 110),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.s),
                  itemBuilder: (context, i) {
                    final sub = items[i];
                    return Dismissible(
                      key: ValueKey(sub.id),
                      direction: DismissDirection.endToStart,
                      background: _SwipeBackground(label: s.delete),
                      onDismissed: (_) => deleteWithUndo(context, sub),
                      child: SubTile(
                        sub: sub,
                        onTap: () => openSubDetail(context, sub),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.tint(p.danger, 1.3),
        borderRadius: Radii.card,
      ),
      padding: const EdgeInsets.only(right: Space.xxl),
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyles.callout.copyWith(
              color: p.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Space.s),
          Icon(Icons.delete_outline_rounded, color: p.danger),
        ],
      ),
    );
  }
}
