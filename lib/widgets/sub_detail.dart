import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'service_avatar.dart';
import 'sub_actions.dart';
import 'ui.dart';

/// Detail card with a scale + fade entrance. Actions close the card first and
/// then run against the screen underneath, so toasts land in the right place.
Future<void> showSubDetail(BuildContext context, Subscription sub) {
  final p = context.palette;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: S.of(context).close,
    barrierColor: p.scrim,
    transitionDuration: Motion.base,
    pageBuilder: (dialogContext, _, _) =>
        _DetailCard(id: sub.id, hostContext: context),
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Motion.enter);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.id, required this.hostContext});

  final String id;
  final BuildContext hostContext;

  void _then(BuildContext context, void Function(BuildContext host) action) {
    Navigator.pop(context);
    if (hostContext.mounted) action(hostContext);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final subs = context.watch<SubsProvider>();
    // Re-read by id so the card reflects edits and closes if deleted.
    final sub = subs.all.where((x) => x.id == id).firstOrNull;
    if (sub == null) return const SizedBox.shrink();

    final today = subs.today;
    final next = sub.nextPaymentFrom(today);
    final spent = sub.amount * sub.paymentsUntil(today);
    final differentCurrency = sub.currency != subs.baseCurrency;

    final String? banner = switch (sub.status) {
      SubStatus.trial when sub.firstPayment.isAfter(today) => s.trialUntil(
        s.longDate(sub.firstPayment),
      ),
      SubStatus.canceled when sub.endDate != null => s.canceledOn(
        s.longDate(sub.endDate!),
      ),
      SubStatus.archived => s.archivedHint,
      _ => null,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Layout.dialogWidth),
          child: Material(
            color: p.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.xl),
              side: BorderSide(color: p.stroke),
            ),
            elevation: 12,
            shadowColor: p.shadow,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Space.xxl,
                Space.xxl,
                Space.xxl,
                Space.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ServiceAvatar.of(sub, size: 64),
                  const SizedBox(height: Space.m),
                  Text(
                    sub.name,
                    textAlign: TextAlign.center,
                    style: TextStyles.title1,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    s.money(sub.amount, sub.currency),
                    style: TextStyles.title2.copyWith(
                      color: p.accentText,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    s.cycle(sub.cycle, sub.interval),
                    style: TextStyles.callout.copyWith(color: p.textSecondary),
                  ),
                  if (banner != null) ...[
                    const SizedBox(height: Space.m),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.m,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: p.tint(statusColor(p, sub.status)),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        banner,
                        textAlign: TextAlign.center,
                        style: TextStyles.subhead.copyWith(
                          color: statusColor(p, sub.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.l),
                  Container(
                    decoration: BoxDecoration(
                      color: p.sunken.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(Radii.m),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.l,
                      vertical: Space.xs,
                    ),
                    child: Column(
                      children: [
                        if (differentCurrency)
                          _Row(
                            s.inBase,
                            '≈ ${s.money(subs.toBase(sub, sub.amount), subs.baseCurrency)}',
                          ),
                        _Row(
                          s.nextCharge,
                          next == null
                              ? (sub.cycle == BillingCycle.oneTime &&
                                        !sub.firstPayment.isAfter(today)
                                    ? s.oneTimePaid
                                    : s.noCharge)
                              : next.difference(today).inDays < 7
                              ? '${s.longDate(next)} · ${s.relativeDay(next, today).toLowerCase()}'
                              : s.longDate(next),
                        ),
                        _Row(s.payingSince, s.longDate(sub.firstPayment)),
                        _Row(s.totalSpent, s.money(spent, sub.currency)),
                        _Row(
                          s.categoryLabel,
                          s.category(sub.category),
                          leading: Dot(sub.category.color),
                        ),
                        _Row(
                          s.reminderLabel,
                          s.reminder(sub.remindDaysBefore),
                          last: sub.notes.isEmpty,
                        ),
                        if (sub.notes.isNotEmpty)
                          _Notes(label: s.notesLabel, text: sub.notes),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.l),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: s.edit,
                          icon: Icons.edit_outlined,
                          kind: ButtonKind.secondary,
                          expand: true,
                          onPressed: () => _then(
                            context,
                            (h) => openSubForm(h, existing: sub),
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      AppIconButton(
                        icon: sub.status == SubStatus.archived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        tooltip: sub.status == SubStatus.archived
                            ? s.unarchive
                            : s.archive,
                        onPressed: () =>
                            _then(context, (h) => toggleArchive(h, sub)),
                      ),
                      const SizedBox(width: Space.s),
                      AppIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: s.delete,
                        color: p.danger,
                        onPressed: () =>
                            _then(context, (h) => deleteWithUndo(h, sub)),
                      ),
                    ],
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.leading, this.last = false});
  final String label;
  final String value;
  final Widget? leading;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.stroke)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyles.callout.copyWith(color: p.textSecondary),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyles.callout.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyles.callout.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: Space.xs),
          SizedBox(
            width: double.infinity,
            child: SelectableText(
              text,
              style: TextStyles.callout.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
