import 'package:flutter/foundation.dart';

import '../data/sub_repository.dart';
import '../models/subscription.dart';
import 'settings_provider.dart';

/// One charge of one subscription, with its value in the base currency.
class Payment {
  const Payment(this.sub, this.date, this.baseAmount);
  final Subscription sub;
  final DateTime date;
  final double baseAmount;
}

/// Spend for one calendar month in the base currency.
class MonthlyTotal {
  const MonthlyTotal(this.month, this.total);
  final DateTime month;
  final double total;
}

/// How the visible month compares with the surrounding year.
enum MonthMood { quiet, light, regular, heavy }

/// App-wide subscription state. Every figure it exposes is in the base
/// currency from [SettingsProvider]; changing currency or rates re-notifies.
class SubsProvider extends ChangeNotifier {
  SubsProvider(this._repo, this._settings, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _items = _repo.getAll(fallbackCurrency: _settings.baseCurrency);
    _promoteFinishedTrials();
    _visibleMonth = _monthOf(today);
    _settings.addListener(notifyListeners);
  }

  final SubRepository _repo;
  final SettingsProvider _settings;
  final DateTime Function() _clock;
  late List<Subscription> _items;
  late DateTime _visibleMonth;

  @override
  void dispose() {
    _settings.removeListener(notifyListeners);
    super.dispose();
  }

  DateTime get today => Subscription.dateOnly(_clock());
  String get baseCurrency => _settings.baseCurrency;

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month, 1);

  /// A trial whose first paid day has come is now simply active.
  void _promoteFinishedTrials() {
    final changed = <Subscription>[];
    for (var i = 0; i < _items.length; i++) {
      final s = _items[i];
      if (s.status == SubStatus.trial && !s.firstPayment.isAfter(today)) {
        _items[i] = s.copyWith(status: SubStatus.active);
        changed.add(_items[i]);
      }
    }
    if (changed.isNotEmpty) _repo.putAll(changed);
  }

  // ---- Collections ----------------------------------------------------------

  List<Subscription> get all => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  /// Everything except archived — contributes real charges (canceled ones up
  /// to their end date).
  Iterable<Subscription> get _counted =>
      _items.where((s) => s.status != SubStatus.archived);

  /// Active and trial — used for forecasts and the category split.
  List<Subscription> get recurring =>
      _items.where((s) => s.status.isRecurring).toList();

  double toBase(Subscription s, double amount) =>
      _settings.rates.convert(amount, s.currency, baseCurrency);

  // ---- Month navigation -----------------------------------------------------

  DateTime get visibleMonth => _visibleMonth;
  bool get isCurrentMonth => _visibleMonth == _monthOf(today);

  void goToMonth(DateTime month) {
    final m = _monthOf(month);
    if (m == _visibleMonth) return;
    _visibleMonth = m;
    notifyListeners();
  }

  void nextMonth() =>
      goToMonth(DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1));
  void prevMonth() =>
      goToMonth(DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1));
  void goToToday() => goToMonth(today);

  // ---- Month figures --------------------------------------------------------

  /// All charges in [month], sorted by date then amount.
  List<Payment> paymentsInMonth(DateTime month) {
    final list = <Payment>[];
    for (final s in _counted) {
      for (final d in s.paymentsInMonth(month.year, month.month)) {
        list.add(Payment(s, d, toBase(s, s.amount)));
      }
    }
    list.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : b.baseAmount.compareTo(a.baseAmount);
    });
    return list;
  }

  double totalFor(DateTime month) =>
      paymentsInMonth(month).fold(0.0, (sum, p) => sum + p.baseAmount);

  /// Average monthly spend over the 12 months around [month].
  double yearAverageAround(DateTime month) {
    var sum = 0.0;
    for (var i = -5; i <= 6; i++) {
      sum += totalFor(DateTime(month.year, month.month + i, 1));
    }
    return sum / 12;
  }

  MonthMood moodFor(double total, double average) {
    if (total <= 0) return MonthMood.quiet;
    if (average <= 0) return MonthMood.regular;
    final ratio = total / average;
    if (ratio > 1.15) return MonthMood.heavy;
    if (ratio < 0.85) return MonthMood.light;
    return MonthMood.regular;
  }

  /// Actual spend for the last [count] months, ending with the current one.
  List<MonthlyTotal> lastMonths(int count) {
    final now = today;
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          return MonthlyTotal(m, totalFor(m));
        }(),
    ];
  }

  // ---- Forecasts ------------------------------------------------------------

  double get monthlyForecast =>
      recurring.fold(0.0, (sum, s) => sum + toBase(s, s.monthlyEquivalent));

  double get yearlyForecast => monthlyForecast * 12;

  Map<SubCategory, double> get spendByCategory {
    final map = <SubCategory, double>{};
    for (final s in recurring) {
      final v = toBase(s, s.monthlyEquivalent);
      if (v <= 0) continue;
      map.update(s.category, (x) => x + v, ifAbsent: () => v);
    }
    return map;
  }

  /// Recurring subscriptions ordered by monthly cost, most expensive first.
  List<Subscription> get byMonthlyCost =>
      recurring.where((s) => s.monthlyEquivalent > 0).toList()..sort(
        (a, b) => toBase(
          b,
          b.monthlyEquivalent,
        ).compareTo(toBase(a, a.monthlyEquivalent)),
      );

  /// Charges inside each subscription's own reminder window, soonest first.
  List<Payment> get dueReminders {
    final list = <Payment>[];
    for (final s in _counted) {
      final days = s.remindDaysBefore;
      if (days == null) continue;
      final d = s.nextPaymentFrom(today);
      if (d == null) continue;
      final t = today;
      if (!d.isAfter(DateTime(t.year, t.month, t.day + days))) {
        list.add(Payment(s, d, toBase(s, s.amount)));
      }
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ---- Mutations ------------------------------------------------------------

  /// Inserts or updates. A subscription switched to "canceled" without an end
  /// date is closed today; switching away from "canceled" reopens it.
  Future<void> save(Subscription sub) async {
    var s = sub;
    if (s.status == SubStatus.canceled && s.endDate == null) {
      s = s.copyWith(endDate: () => today);
    } else if (s.status.isRecurring && s.endDate != null) {
      s = s.copyWith(endDate: () => null);
    }
    final i = _items.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      _items[i] = s;
    } else {
      _items.add(s);
    }
    notifyListeners();
    await _repo.put(s);
  }

  /// Removes and returns the subscription so the caller can offer Undo.
  Future<Subscription?> remove(String id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    final removed = _items.removeAt(i);
    notifyListeners();
    await _repo.delete(id);
    return removed;
  }

  Future<void> clearAll() async {
    _items = [];
    notifyListeners();
    await _repo.clear();
  }

  /// Adds or replaces (by id) many subscriptions — used by import and demo.
  Future<int> upsertAll(List<Subscription> subs) async {
    for (final s in subs) {
      final i = _items.indexWhere((x) => x.id == s.id);
      if (i >= 0) {
        _items[i] = s;
      } else {
        _items.add(s);
      }
    }
    _promoteFinishedTrials();
    notifyListeners();
    final ids = {for (final s in subs) s.id};
    await _repo.putAll(_items.where((s) => ids.contains(s.id)));
    return subs.length;
  }
}
