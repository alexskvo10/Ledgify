import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../app_info.dart';
import '../data/backup.dart';
import '../data/demo_data.dart';
import '../data/rates_client.dart';
import '../l10n/strings.dart';
import '../models/currency.dart';
import '../state/settings_provider.dart';
import '../state/subs_provider.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/budget.dart';
import '../widgets/ui.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final settings = context.watch<SettingsProvider>();
    final subs = context.watch<SubsProvider>();
    final cur = Currency.of(settings.baseCurrency);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: p.glow),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            titleSpacing: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: Space.m),
              child: Center(
                child: AppIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: '${s.back}  (Esc)',
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            leadingWidth: 64,
            title: Text(s.settings, style: TextStyles.title2),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.xxxl),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Appearance ──
                      SectionLabel(s.appearance),
                      _Group(
                        children: [
                          _Row(
                            icon: Icons.contrast_rounded,
                            title: s.theme,
                            trailing: _Choice<ThemeMode>(
                              value: settings.themeMode,
                              options: {
                                ThemeMode.system: s.themeSystem,
                                ThemeMode.light: s.themeLight,
                                ThemeMode.dark: s.themeDark,
                              },
                              onChanged: settings.setThemeMode,
                            ),
                          ),
                          _Row(
                            icon: Icons.translate_rounded,
                            title: s.language,
                            trailing: _Choice<String>(
                              value: settings.locale.languageCode,
                              options: const {'ru': 'Русский', 'en': 'English'},
                              onChanged: (v) => settings.setLocale(Locale(v)),
                            ),
                          ),
                        ],
                      ),

                      // ── Money ──
                      SectionLabel(s.moneySection),
                      _Group(
                        children: [
                          _Row(
                            icon: Icons.payments_outlined,
                            title: s.baseCurrency,
                            subtitle: s.baseCurrencyHint,
                            trailing: _CurrencyMenu(
                              value: settings.baseCurrency,
                              onChanged: settings.setBaseCurrency,
                            ),
                          ),
                          _Row(
                            icon: Icons.currency_exchange_rounded,
                            title: s.rates,
                            subtitle: settings.ratesUpdatedAt == null
                                ? s.ratesBuiltIn
                                : s.ratesUpdated(
                                    s.dateTime(settings.ratesUpdatedAt!),
                                  ),
                            onTap: () => showAppSheet(
                              context,
                              (_) => const _RatesSheet(),
                            ),
                          ),
                          _Row(
                            icon: Icons.savings_outlined,
                            title: s.budget,
                            subtitle: settings.budget > 0
                                ? s.money(
                                    settings.budget,
                                    cur.code,
                                    whole: true,
                                  )
                                : s.budgetEmpty,
                            onTap: () => showBudgetDialog(context),
                          ),
                        ],
                      ),

                      // ── Data ──
                      SectionLabel(s.data),
                      _Group(
                        children: [
                          _Row(
                            icon: Icons.save_alt_rounded,
                            title: s.export,
                            subtitle: _isDesktop
                                ? s.exportBody
                                : s.exportBodyMobile,
                            onTap: subs.isEmpty ? null : () => _export(context),
                          ),
                          _Row(
                            icon: Icons.content_paste_go_rounded,
                            title: s.importTitle,
                            subtitle: s.importBody,
                            onTap: () => _import(context),
                          ),
                          _Row(
                            icon: Icons.auto_awesome_outlined,
                            title: s.demo,
                            subtitle: s.demoBody,
                            onTap: () {
                              subs.upsertAll(buildDemoData(subs.today));
                              toast(context, s.demoAdded);
                            },
                          ),
                        ],
                      ),

                      // ── Danger ──
                      SectionLabel(s.danger),
                      _Group(
                        children: [
                          _Row(
                            icon: Icons.delete_forever_outlined,
                            title: s.deleteAll,
                            subtitle: s.deleteAllBody(subs.all.length),
                            danger: true,
                            onTap: subs.isEmpty
                                ? null
                                : () => _deleteAll(context),
                          ),
                        ],
                      ),

                      if (_isDesktop) ...[
                        SectionLabel(s.shortcuts),
                        _Group(
                          children: [
                            for (final (keys, action) in s.shortcutList)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: Space.l,
                                  vertical: Space.m,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        action,
                                        style: TextStyles.callout,
                                      ),
                                    ),
                                    _Kbd(keys),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],

                      // ── About ──
                      SectionLabel(s.about),
                      AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppMark(size: 44),
                            const SizedBox(width: Space.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.appName, style: TextStyles.headline),
                                  Text(
                                    s.version(appVersion),
                                    style: TextStyles.footnote.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: Space.s),
                                  Text(
                                    s.aboutBody,
                                    style: TextStyles.subhead.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: Space.xs),
                                  SelectableText(
                                    appRepo,
                                    style: TextStyles.footnote.copyWith(
                                      color: p.textTertiary,
                                    ),
                                  ),
                                ],
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
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final s = S.of(context);
    final subs = context.read<SubsProvider>();
    final json = Backup.encode(subs.all, baseCurrency: subs.baseCurrency);
    await Clipboard.setData(ClipboardData(text: json));
    String? path;
    if (_isDesktop) {
      try {
        final docs = await getApplicationDocumentsDirectory();
        final dir = Directory('${docs.path}${Platform.pathSeparator}Ledgify');
        await dir.create(recursive: true);
        final file = File(
          '${dir.path}${Platform.pathSeparator}${Backup.fileName(DateTime.now())}',
        );
        await file.writeAsString(json);
        path = file.path;
      } catch (_) {
        path = null; // the clipboard copy still succeeded
      }
    }
    if (!context.mounted) return;
    toast(context, path != null ? s.exported(path) : s.copied);
  }

  Future<void> _import(BuildContext context) async {
    final s = S.of(context);
    final subs = context.read<SubsProvider>();
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      toast(context, s.importError('empty'));
      return;
    }
    try {
      final list = Backup.decode(text, fallbackCurrency: subs.baseCurrency);
      final n = await subs.upsertAll(list);
      if (context.mounted) toast(context, s.imported(n));
    } on FormatException catch (e) {
      if (context.mounted) toast(context, s.importError(e.message));
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final s = S.of(context);
    final subs = context.read<SubsProvider>();
    final ok = await confirm(
      context,
      title: s.deleteAllTitle,
      message: s.deleteAllWarning,
      action: s.deleteAllConfirm,
      danger: true,
    );
    if (!ok || !context.mounted) return;
    HapticFeedback.heavyImpact();
    await subs.clearAll();
    if (context.mounted) toast(context, s.allDeleted);
  }
}

/// Rounded card holding rows separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: Space.l, color: p.stroke),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = danger ? p.danger : p.textPrimary;
    final enabled = onTap != null || trailing != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.l,
            vertical: Space.m,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: p.tint(danger ? p.danger : p.accent),
                  borderRadius: BorderRadius.circular(Radii.s),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: danger ? p.danger : p.accentText,
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyles.callout.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyles.footnote.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Space.m),
                trailing!,
              ] else if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact dropdown-style single choice.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<T>(
      initialValue: value,
      tooltip: '',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final e in options.entries)
          CheckedPopupMenuItem(
            value: e.key,
            checked: e.key == value,
            child: Text(e.value),
          ),
      ],
      child: _MenuPill(text: options[value] ?? '', palette: p),
    );
  }
}

class _CurrencyMenu extends StatelessWidget {
  const _CurrencyMenu({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Currency.of(value);
    return PopupMenuButton<String>(
      initialValue: value,
      tooltip: '',
      onSelected: onChanged,
      constraints: const BoxConstraints(maxHeight: 400),
      itemBuilder: (_) => [
        for (final x in Currency.all)
          CheckedPopupMenuItem(
            value: x.code,
            checked: x.code == value,
            child: Text('${x.code}  ${x.symbol}'),
          ),
      ],
      child: _MenuPill(text: '${c.code} ${c.symbol}', palette: context.palette),
    );
  }
}

class _MenuPill extends StatelessWidget {
  const _MenuPill({required this.text, required this.palette});
  final String text;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.m, 7, Space.s, 7),
      decoration: BoxDecoration(
        color: p.sunken,
        borderRadius: BorderRadius.circular(Radii.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyles.subhead.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 2),
          Icon(Icons.expand_more_rounded, size: 18, color: p.textSecondary),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd(this.keys);
  final String keys;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 3),
      decoration: BoxDecoration(
        color: p.sunken,
        borderRadius: BorderRadius.circular(Radii.xs),
        border: Border.all(color: p.strokeStrong),
      ),
      child: Text(
        keys,
        style: TextStyles.footnote.copyWith(
          fontWeight: FontWeight.w600,
          color: p.textSecondary,
        ),
      ),
    );
  }
}

/// Exchange-rate editor: every known currency vs. USD, editable by hand,
/// plus "update from the internet" and "reset".
class _RatesSheet extends StatefulWidget {
  const _RatesSheet();

  @override
  State<_RatesSheet> createState() => _RatesSheetState();
}

class _RatesSheetState extends State<_RatesSheet> {
  bool _loading = false;

  Future<void> _update() async {
    final s = S.of(context);
    final settings = context.read<SettingsProvider>();
    setState(() => _loading = true);
    try {
      final rates = await fetchRates();
      await settings.replaceRates(rates, DateTime.now());
      if (mounted) toast(context, s.ratesOk);
    } catch (_) {
      if (mounted) toast(context, s.ratesFail);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.palette;
    final settings = context.watch<SettingsProvider>();
    final table = settings.rateTable;

    return SheetFrame(
      title: s.rates,
      footer: Row(
        children: [
          Expanded(
            child: AppButton(
              label: s.resetRates,
              kind: ButtonKind.secondary,
              expand: true,
              onPressed: _loading ? null : settings.resetRates,
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: AppButton(
              label: s.updateRates,
              icon: _loading ? null : Icons.cloud_download_outlined,
              expand: true,
              onPressed: _loading ? null : _update,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) const LinearProgressIndicator(),
          Text(
            settings.ratesUpdatedAt == null
                ? s.ratesBuiltIn
                : s.ratesUpdated(s.dateTime(settings.ratesUpdatedAt!)),
            style: TextStyles.callout.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: Space.xs),
          Text(
            s.ratesPrivacy,
            style: TextStyles.footnote.copyWith(color: p.textTertiary),
          ),
          const SizedBox(height: Space.l),
          for (final c in Currency.all.where((c) => c.code != 'USD'))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _RateField(
                // Rebuild the field when the value changes from outside.
                key: ValueKey('${c.code}-${table[c.code]}'),
                currency: c,
                value: table[c.code] ?? 1,
                onSubmit: (v) => settings.setRate(c.code, v),
              ),
            ),
        ],
      ),
    );
  }
}

class _RateField extends StatefulWidget {
  const _RateField({
    super.key,
    required this.currency,
    required this.value,
    required this.onSubmit,
  });

  final Currency currency;
  final double value;
  final ValueChanged<double> onSubmit;

  @override
  State<_RateField> createState() => _RateFieldState();
}

class _RateFieldState extends State<_RateField> {
  late final _ctrl = TextEditingController(text: _plain(widget.value));
  final _focus = FocusNode();

  static String _plain(double v) {
    final t = v.toStringAsFixed(v >= 100 ? 2 : 4);
    return t.contains('.') ? t.replaceFirst(RegExp(r'\.?0+$'), '') : t;
  }

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  void _commit() {
    final v = S.parseAmount(_ctrl.text);
    if (v != null && v > 0 && v != widget.value) {
      widget.onSubmit(v);
    } else {
      _ctrl.text = _plain(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            '${widget.currency.code} ${widget.currency.symbol}',
            style: TextStyles.callout.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(12),
            ],
            textAlign: TextAlign.end,
            style: TextStyles.callout.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              isDense: true,
              prefixText: '1 USD = ',
              prefixStyle: TextStyles.footnote.copyWith(color: p.textTertiary),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Space.m,
                vertical: 10,
              ),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ],
    );
  }
}
