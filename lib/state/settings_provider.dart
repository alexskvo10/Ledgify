import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/storage.dart';
import '../models/currency.dart';

/// Persisted preferences: theme, language, base currency, exchange rates,
/// monthly budget and the onboarding flag.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider([Box? box]) : _box = box ?? Hive.box(Boxes.settings) {
    _load();
  }

  final Box _box;

  static const _kTheme = 'themeMode';
  static const _kLocale = 'localeCode';
  static const _kCurrency = 'baseCurrency';
  static const _kLegacyCurrency = 'defaultCurrency';
  static const _kRates = 'rates';
  static const _kRatesAt = 'ratesUpdatedAt';
  static const _kBudget = 'monthly_budget';
  static const _kOnboarding = 'onboarding_complete';

  late ThemeMode _themeMode;
  late Locale _locale;
  late String _baseCurrency;
  late Map<String, double> _rates;
  DateTime? _ratesUpdatedAt;
  late double _budget;
  late bool _onboardingDone;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get baseCurrency => _baseCurrency;
  Rates get rates => Rates(_rates);
  Map<String, double> get rateTable => Map.unmodifiable(_rates);

  /// `null` while the built-in approximate rates are in use.
  DateTime? get ratesUpdatedAt => _ratesUpdatedAt;

  /// Monthly budget in the base currency; 0 = not set.
  double get budget => _budget;
  bool get onboardingDone => _onboardingDone;

  void _load() {
    _themeMode = switch (_box.get(_kTheme)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final systemRu =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'ru';
    final code = _box.get(_kLocale) as String? ?? (systemRu ? 'ru' : 'en');
    _locale = Locale(code == 'ru' ? 'ru' : 'en');

    final stored = _box.get(_kCurrency);
    if (stored is String && Currency.isKnown(stored)) {
      _baseCurrency = stored;
    } else {
      final fallback = _locale.languageCode == 'ru' ? 'RUB' : 'USD';
      final legacy = _box.get(_kLegacyCurrency);
      _baseCurrency = legacy is String
          ? Currency.codeFromLegacySymbol(legacy, fallback)
          : fallback;
    }

    _rates = Map.of(Currency.defaultRates);
    final raw = _box.get(_kRates);
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is num && v > 0) _rates[k] = v.toDouble();
      });
    }
    final at = _box.get(_kRatesAt);
    _ratesUpdatedAt = at is int
        ? DateTime.fromMillisecondsSinceEpoch(at)
        : null;

    final b = _box.get(_kBudget);
    _budget = b is num && b > 0 ? b.toDouble() : 0;

    _onboardingDone = _box.get(_kOnboarding) == true;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _box.put(_kTheme, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    await _box.put(_kLocale, locale.languageCode);
  }

  /// Changing the base currency also converts the budget so it keeps its
  /// real value.
  Future<void> setBaseCurrency(String code) async {
    if (!Currency.isKnown(code) || code == _baseCurrency) return;
    final budget = rates.convert(_budget, _baseCurrency, code);
    _baseCurrency = code;
    _budget = _roundMoney(budget);
    notifyListeners();
    await _box.putAll({_kCurrency: code, _kBudget: _budget});
  }

  /// Sets one rate by hand (units of [code] per 1 USD).
  Future<void> setRate(String code, double perUsd) async {
    if (perUsd <= 0 || code == 'USD') return;
    _rates[code] = perUsd;
    notifyListeners();
    await _box.put(_kRates, Map<String, double>.of(_rates));
  }

  Future<void> replaceRates(Map<String, double> fresh, DateTime at) async {
    _rates = {...Currency.defaultRates, ...fresh};
    _ratesUpdatedAt = at;
    notifyListeners();
    await _box.putAll({
      _kRates: Map<String, double>.of(_rates),
      _kRatesAt: at.millisecondsSinceEpoch,
    });
  }

  Future<void> resetRates() async {
    _rates = Map.of(Currency.defaultRates);
    _ratesUpdatedAt = null;
    notifyListeners();
    await _box.deleteAll([_kRates, _kRatesAt]);
  }

  Future<void> setBudget(double value) async {
    _budget = value > 0 ? _roundMoney(value) : 0;
    notifyListeners();
    await _box.put(_kBudget, _budget);
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    notifyListeners();
    await _box.put(_kOnboarding, true);
  }

  static double _roundMoney(double v) => (v * 100).roundToDouble() / 100;
}
