import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/currency.dart';
import '../state/settings_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';

/// Asks for the monthly budget in the base currency. Empty or 0 removes it.
Future<void> showBudgetDialog(BuildContext context) async {
  final settings = context.read<SettingsProvider>();
  final result = await showDialog<double>(
    context: context,
    barrierColor: context.palette.scrim,
    builder: (_) => _BudgetDialog(
      initial: settings.budget,
      currency: Currency.of(settings.baseCurrency),
    ),
  );
  if (result != null) await settings.setBudget(result);
}

/// Stateful so the text controller lives exactly as long as the field.
class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.initial, required this.currency});
  final double initial;
  final Currency currency;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final _ctrl = TextEditingController(
    text: widget.initial > 0 ? widget.initial.round().toString() : '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, S.parseAmount(_ctrl.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final cur = widget.currency;
    return AlertDialog(
      title: Text(s.budget),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Layout.dialogWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.budgetDialogBody),
            const SizedBox(height: Space.l),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                LengthLimitingTextInputFormatter(12),
              ],
              style: TextStyles.title2,
              decoration: InputDecoration(
                suffixText: '${cur.code} ${cur.symbol}',
                hintText: '0',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initial > 0)
          TextButton(
            onPressed: () => Navigator.pop(context, 0.0),
            style: TextButton.styleFrom(foregroundColor: p.danger),
            child: Text(s.remove),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}

/// Thin progress bar: spent vs. monthly budget, turns red when exceeded.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.spent,
    required this.budget,
    required this.currency,
  });
  final double spent;
  final double budget;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final over = spent > budget;
    final color = over ? p.danger : p.accent;
    final ratio = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.budgetOf(
                  s.money(spent, currency, whole: true),
                  s.money(budget, currency, whole: true),
                ),
                style: TextStyles.footnote.copyWith(color: p.textSecondary),
              ),
            ),
            Text(
              over
                  ? s.budgetOver(s.money(spent - budget, currency, whole: true))
                  : s.budgetLeft(
                      s.money(budget - spent, currency, whole: true),
                    ),
              style: TextStyles.footnote.copyWith(
                color: over ? p.danger : p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ratio),
            duration: Motion.counter,
            curve: Motion.enter,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: color,
              backgroundColor: p.sunken,
            ),
          ),
        ),
      ],
    );
  }
}
