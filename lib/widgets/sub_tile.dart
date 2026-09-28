import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'service_avatar.dart';
import 'ui.dart';

/// One subscription row: avatar, name + meta, amount + next charge.
/// Shared by the list, the day sheet and the month payment list.
class SubTile extends StatelessWidget {
  const SubTile({
    super.key,
    required this.sub,
    required this.onTap,
    this.date,
    this.compact = false,
  });

  final Subscription sub;
  final VoidCallback onTap;

  /// Show this charge date instead of the next one (month list).
  final DateTime? date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.read<SubsProvider>();
    final today = subs.today;
    final next = date ?? sub.nextPaymentFrom(today);
    final soon =
        next != null &&
        date == null &&
        next.difference(today).inDays <= 3 &&
        sub.status != SubStatus.archived;

    final meta = [
      s.cycle(sub.cycle, sub.interval),
      s.category(sub.category),
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${sub.name}, ${s.money(sub.amount, sub.currency)}',
      excludeSemantics: false,
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.symmetric(
          horizontal: Space.m + 2,
          vertical: compact ? Space.s + 2 : Space.m + 2,
        ),
        child: Row(
          children: [
            ServiceAvatar.of(sub, size: compact ? 36 : 42),
            const SizedBox(width: Space.m + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sub.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.headline.copyWith(
                            color: sub.status.isRecurring
                                ? p.textPrimary
                                : p.textSecondary,
                          ),
                        ),
                      ),
                      if (sub.status != SubStatus.active) ...[
                        const SizedBox(width: Space.s),
                        StatusTag(sub.status),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.footnote.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  s.money(sub.amount, sub.currency),
                  style: TextStyles.amount.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  next == null
                      ? (sub.cycle == BillingCycle.oneTime
                            ? s.oneTimePaid
                            : s.noCharge)
                      : (date != null
                            ? s.dayMonth(next)
                            : s.relativeDay(next, today)),
                  style: TextStyles.footnote.copyWith(
                    color: soon ? p.warning : p.textTertiary,
                    fontWeight: soon ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
