import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/strings.dart';
import '../models/currency.dart';
import '../models/presets.dart';
import '../models/subscription.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'service_avatar.dart';
import 'ui.dart';

/// Add / edit form shown in a bottom sheet.
class SubForm extends StatefulWidget {
  const SubForm({super.key, this.existing});
  final Subscription? existing;

  @override
  State<SubForm> createState() => _SubFormState();
}

class _SubFormState extends State<SubForm> {
  static const _palette = [
    0xFF34C759,
    0xFF0A84FF,
    0xFF5E5CE6,
    0xFFAF52DE,
    0xFFFF2D55,
    0xFFFF3B30,
    0xFFFF9F0A,
    0xFFE5B800,
    0xFF32ADE6,
    0xFF1DB954,
    0xFF8E8E93,
    0xFF37352F,
  ];

  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _icon;
  late final TextEditingController _notes;
  late String _currency;
  late BillingCycle _cycle;
  late int _interval;
  late DateTime _first;
  DateTime? _end;
  late SubStatus _status;
  late SubCategory _category;
  late int _color;
  int? _remind;

  String? _nameError;
  String? _amountError;
  late final Subscription _initial;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final subs = context.read<SubsProvider>();
    _initial =
        widget.existing ??
        Subscription(
          id: const Uuid().v4(),
          name: '',
          amount: 0,
          currency: subs.baseCurrency,
          firstPayment: subs.today,
          remindDaysBefore: 1,
        );
    final e = _initial;
    _name = TextEditingController(text: e.name);
    _amount = TextEditingController(
      text: _isEdit ? _formatAmount(e.amount) : '',
    );
    _icon = TextEditingController(text: e.icon);
    _notes = TextEditingController(text: e.notes);
    _currency = e.currency;
    _cycle = e.cycle;
    _interval = e.interval;
    _first = e.firstPayment;
    _end = e.endDate;
    _status = e.status;
    _category = e.category;
    _color = e.accentColor;
    _remind = e.remindDaysBefore;
  }

  static String _formatAmount(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _icon.dispose();
    _notes.dispose();
    super.dispose();
  }

  Subscription _build() => _initial.copyWith(
    name: _name.text.trim(),
    amount: S.parseAmount(_amount.text) ?? 0,
    currency: _currency,
    cycle: _cycle,
    interval: _cycle == BillingCycle.oneTime ? 1 : _interval,
    firstPayment: Subscription.dateOnly(_first),
    endDate: () => _status == SubStatus.canceled ? _end : null,
    status: _status,
    category: _category,
    accentColor: _color,
    icon: _icon.text.trim().isEmpty ? '💳' : _icon.text.trim(),
    remindDaysBefore: () => _remind,
    notes: _notes.text.trim(),
  );

  bool get _dirty {
    if (!_isEdit) {
      // A new form counts as touched once the user typed something.
      return _name.text.trim().isNotEmpty ||
          _amount.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty;
    }
    // Normalise the original the same way _build() does (older versions
    // stored a time of day in firstPayment), then compare field by field.
    final original = _initial
        .copyWith(firstPayment: Subscription.dateOnly(_initial.firstPayment))
        .toMap();
    final current = _build().toMap();
    return original.keys.any((k) => original[k] != current[k]);
  }

  void _applyPreset(ServicePreset p) {
    HapticFeedback.selectionClick();
    setState(() {
      _name.text = p.name;
      _icon.text = p.icon;
      _color = p.color;
      _category = p.category;
      _cycle = p.cycle;
      _nameError = null;
    });
  }

  Future<void> _save() async {
    final s = S.of(context);
    final amount = S.parseAmount(_amount.text);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? s.nameRequired : null;
      _amountError = (amount == null || amount <= 0) ? s.amountInvalid : null;
    });
    if (_nameError != null || _amountError != null) {
      HapticFeedback.heavyImpact();
      return;
    }
    final sub = _build();
    final subs = context.read<SubsProvider>();
    HapticFeedback.mediumImpact();
    toast(context, _isEdit ? s.updatedMsg(sub.name) : s.addedMsg(sub.name));
    Navigator.pop(context);
    await subs.save(sub);
  }

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final s = S.of(context);
    final ok = await confirm(
      context,
      title: s.discardTitle,
      action: s.discard,
      danger: true,
    );
    if (ok && mounted) Navigator.pop(context);
  }

  static final _minDate = DateTime(1990);
  static final _maxDate = DateTime(2100, 12, 31);

  /// The picker asserts when the initial date is outside its range, and
  /// imported data can hold any date — so clamp it first.
  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial.isBefore(_minDate)
        ? _minDate
        : (initial.isAfter(_maxDate) ? _maxDate : initial),
    firstDate: _minDate,
    lastDate: _maxDate,
  );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;

    final dateLabel = switch ((_status, _cycle)) {
      (SubStatus.trial, _) => s.trialEnds,
      (_, BillingCycle.oneTime) => s.paymentDate,
      _ => s.firstPayment,
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SheetFrame(
        title: _isEdit ? s.editSub : s.newSub,
        onClose: _close,
        footer: AppButton(
          label: _isEdit ? s.save : s.addButton,
          expand: true,
          onPressed: _save,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isEdit) ...[
              _Label(s.popular),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ServicePreset.all.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.s),
                  itemBuilder: (_, i) {
                    final pr = ServicePreset.all[i];
                    return AppChip(
                      label: pr.name,
                      selected: _name.text == pr.name,
                      color: Color(pr.color),
                      leading: ServiceAvatar(
                        icon: pr.icon,
                        color: Color(pr.color),
                        size: 20,
                      ),
                      onTap: () => _applyPreset(pr),
                    );
                  },
                ),
              ),
              const SizedBox(height: Space.l),
            ],

            // ── Identity ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live preview of how the service will look everywhere.
                ServiceAvatar(
                  icon: _icon.text.trim().isEmpty ? '💳' : _icon.text.trim(),
                  color: Color(_color),
                  size: 50,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: s.name,
                      errorText: _nameError,
                      counterText: '',
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                      LengthLimitingTextInputFormatter(14),
                    ],
                    style: TextStyles.headline,
                    decoration: InputDecoration(
                      labelText: s.amount,
                      errorText: _amountError,
                    ),
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                    onSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: Space.m),
                SizedBox(
                  width: 128,
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(Radii.m),
                    dropdownColor: p.raised,
                    menuMaxHeight: 360,
                    decoration: InputDecoration(labelText: s.currency),
                    items: [
                      for (final c in Currency.all)
                        DropdownMenuItem(
                          value: c.code,
                          child: Text(
                            '${c.code}  ${c.symbol}',
                            style: TextStyles.callout,
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _currency = v ?? _currency),
                  ),
                ),
              ],
            ),

            // ── Billing ──
            _Label(s.billing),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final c in BillingCycle.values)
                  AppChip(
                    label: s.cycleName(c),
                    selected: _cycle == c,
                    onTap: () => setState(() => _cycle = c),
                  ),
              ],
            ),
            if (_cycle != BillingCycle.oneTime) ...[
              const SizedBox(height: Space.m),
              _Stepper(
                label: s.cycle(_cycle, _interval),
                value: _interval,
                onChanged: (v) => setState(() => _interval = v),
              ),
            ],
            const SizedBox(height: Space.m),
            _DateField(
              label: dateLabel,
              value: s.longDate(_first),
              onTap: () async {
                final d = await _pickDate(_first);
                if (d != null) setState(() => _first = d);
              },
            ),

            // ── Status ──
            _Label(s.statusLabel),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final st in SubStatus.values)
                  AppChip(
                    label: s.status(st),
                    selected: _status == st,
                    color: statusColor(p, st),
                    onTap: () => setState(() {
                      _status = st;
                      if (st == SubStatus.canceled) {
                        _end ??= context.read<SubsProvider>().today;
                      }
                    }),
                  ),
              ],
            ),
            if (_status == SubStatus.canceled) ...[
              const SizedBox(height: Space.m),
              _DateField(
                label: s.endDate,
                value: s.longDate(_end ?? _first),
                onTap: () async {
                  final d = await _pickDate(_end ?? DateTime.now());
                  if (d != null) setState(() => _end = d);
                },
              ),
            ],

            // ── Category ──
            _Label(s.categoryLabel),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final c in SubCategory.values)
                  AppChip(
                    label: s.category(c),
                    selected: _category == c,
                    color: c.color,
                    leading: Dot(c.color),
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),

            // ── Look: icon + colour ──
            _Label(s.colorLabel),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _icon,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                      labelText: s.icon,
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(
                    s.iconHint,
                    style: TextStyles.footnote.copyWith(color: p.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.m,
              runSpacing: Space.m,
              children: [
                for (final c in {..._palette, _color})
                  _Swatch(
                    color: Color(c),
                    selected: c == _color,
                    onTap: () => setState(() => _color = c),
                  ),
              ],
            ),

            // ── Reminder ──
            _Label(s.reminderLabel),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final r in <int?>[null, ...reminderOptions])
                  AppChip(
                    label: s.reminder(r),
                    selected: _remind == r,
                    onTap: () => setState(() => _remind = r),
                  ),
              ],
            ),

            // ── Notes ──
            _Label(s.notesLabel),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: s.notesHint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xl, bottom: Space.s),
    child: Text(
      text,
      style: TextStyles.subhead.copyWith(
        color: context.palette.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.sunken,
      borderRadius: Radii.control,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.l,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(Icons.event_rounded, size: 20, color: p.textSecondary),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyles.footnote.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyles.callout),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget btn(IconData icon, String tip, int? to) => AppIconButton(
      icon: icon,
      tooltip: tip,
      onPressed: to == null ? null : () => onChanged(to),
      color: to == null ? p.textTertiary.withValues(alpha: 0.4) : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.l,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(color: p.sunken, borderRadius: Radii.control),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyles.callout)),
          btn(Icons.remove_rounded, '−', value > 1 ? value - 1 : null),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyles.headline,
            ),
          ),
          btn(Icons.add_rounded, '+', value < 99 ? value + 1 : null),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? p.textPrimary : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: p.stroke),
            ),
          ),
        ),
      ),
    );
  }
}
