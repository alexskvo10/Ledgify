import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/subscription.dart';
import '../state/subs_provider.dart';
import 'sub_detail.dart';
import 'sub_form.dart';
import 'ui.dart';

/// The only place that deletes, archives, opens the form or the detail card.
/// Every screen calls these, so behaviour (undo, toasts) is identical.

Future<void> openSubForm(BuildContext context, {Subscription? existing}) =>
    showAppSheet(
      context,
      (_) => SubForm(existing: existing),
      enableDrag: false,
    );

Future<void> openSubDetail(BuildContext context, Subscription sub) =>
    showSubDetail(context, sub);

/// Deletes immediately and offers Undo in a toast.
///
/// Everything needed from [context] is read up front: the row that called us
/// is removed by the delete itself, so its context dies mid-way.
Future<void> deleteWithUndo(BuildContext context, Subscription sub) async {
  final s = S.of(context);
  final subs = context.read<SubsProvider>();
  final messenger = ScaffoldMessenger.of(context);
  HapticFeedback.mediumImpact();
  final removed = await subs.remove(sub.id);
  if (removed == null) return;
  toastOn(
    messenger,
    s.deletedMsg(removed.name),
    actionLabel: s.undo,
    onAction: () => subs.save(removed),
  );
}

/// Archives, or brings back from the archive (as canceled if it had an end
/// date, otherwise active), with Undo.
Future<void> toggleArchive(BuildContext context, Subscription sub) async {
  final s = S.of(context);
  final subs = context.read<SubsProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final archiving = sub.status != SubStatus.archived;
  await subs.save(
    sub.copyWith(
      status: archiving
          ? SubStatus.archived
          : (sub.endDate != null ? SubStatus.canceled : SubStatus.active),
    ),
  );
  toastOn(
    messenger,
    archiving ? s.archivedMsg(sub.name) : s.restoredMsg(sub.name),
    actionLabel: s.undo,
    onAction: () => subs.save(sub),
  );
}
