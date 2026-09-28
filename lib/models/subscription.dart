import 'dart:math' as math;
import 'dart:ui' show Color;

import 'currency.dart';

/// How often a subscription is charged. Combined with [Subscription.interval]
/// this covers "every 3 months", "every 2 weeks" and so on.
enum BillingCycle { weekly, monthly, yearly, oneTime }

/// Lifecycle of a subscription.
///
/// * active / trial — recurring, counts toward forecasts;
/// * canceled — stopped on [Subscription.endDate]; past charges still count;
/// * archived — hidden from every figure, kept only for reference.
enum SubStatus { active, trial, canceled, archived }

extension SubStatusX on SubStatus {
  bool get isRecurring => this == SubStatus.active || this == SubStatus.trial;
}

/// Spending categories, each with its own accent colour.
enum SubCategory {
  entertainment(Color(0xFFAF52DE)),
  lifestyle(Color(0xFFFF2D55)),
  utilities(Color(0xFF0A84FF)),
  productivity(Color(0xFFFF9F0A)),
  health(Color(0xFF30B94D)),
  education(Color(0xFF32ADE6)),
  finance(Color(0xFFE5B800)),
  shopping(Color(0xFFFF6B3D)),
  other(Color(0xFF8E8E93));

  const SubCategory(this.color);
  final Color color;
}

/// Reminder options, in days before the charge.
const reminderOptions = <int>[0, 1, 3, 7];

/// A single subscription / recurring payment.
///
/// Stored in Hive as a flat `Map` of primitives (no code generation), which
/// keeps the project simple and behaves identically on Windows and Android.
class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    this.currency = 'USD',
    this.cycle = BillingCycle.monthly,
    this.interval = 1,
    required this.firstPayment,
    this.endDate,
    this.category = SubCategory.other,
    this.status = SubStatus.active,
    this.accentColor = 0xFF34C759,
    this.icon = '💳',
    this.remindDaysBefore,
    this.notes = '',
  });

  final String id;
  final String name;
  final double amount;

  /// ISO currency code, see [Currency].
  final String currency;
  final BillingCycle cycle;

  /// Charge every [interval] cycles (≥ 1).
  final int interval;

  /// Anchor date the recurrence is based on (for a trial — the first paid day).
  final DateTime firstPayment;

  /// Last day a charge can happen (set when a subscription is canceled).
  final DateTime? endDate;
  final SubCategory category;
  final SubStatus status;
  final int accentColor;

  /// Emoji or short text shown on the calendar.
  final String icon;

  /// Remind this many days before each charge; `null` = no reminder.
  final int? remindDaysBefore;
  final String notes;

  Color get color => Color(accentColor);
  Currency get currencyInfo => Currency.of(currency);

  // ---- Recurrence maths -----------------------------------------------------
  //
  // Charges are generated directly (k-th charge = anchor + k·period) instead of
  // testing every day, so far-future months and long intervals stay cheap.
  // Calendar arithmetic (DateTime(y, m, d + n)) is used instead of Duration so
  // daylight-saving shifts can never move a charge to another day.

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static int _dayDiff(DateTime a, DateTime b) => DateTime.utc(
    a.year,
    a.month,
    a.day,
  ).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

  int get _step => math.max(1, interval);

  /// Last day a charge may fall on, or `null` for "no limit".
  /// A canceled subscription without an end date never charged (legacy data).
  DateTime? get _lastAllowed {
    if (endDate != null) return dateOnly(endDate!);
    if (status == SubStatus.canceled) {
      return dateOnly(firstPayment).subtract(const Duration(days: 1));
    }
    return null;
  }

  /// The k-th charge date (k ≥ 0), ignoring [endDate].
  DateTime? _nth(int k) {
    final s = firstPayment;
    switch (cycle) {
      case BillingCycle.oneTime:
        return k == 0 ? dateOnly(s) : null;
      case BillingCycle.weekly:
        return DateTime(s.year, s.month, s.day + 7 * _step * k);
      case BillingCycle.monthly:
        final m = DateTime(s.year, s.month + _step * k, 1);
        return DateTime(
          m.year,
          m.month,
          math.min(s.day, _daysInMonth(m.year, m.month)),
        );
      case BillingCycle.yearly:
        final y = s.year + _step * k;
        return DateTime(y, s.month, math.min(s.day, _daysInMonth(y, s.month)));
    }
  }

  /// Index of a charge that is guaranteed to be on or before [from].
  int _firstIndexNear(DateTime from) {
    final s = firstPayment;
    final est = switch (cycle) {
      BillingCycle.oneTime => 0,
      BillingCycle.weekly => _dayDiff(from, s) ~/ (7 * _step),
      BillingCycle.monthly =>
        ((from.year - s.year) * 12 + from.month - s.month) ~/ _step,
      BillingCycle.yearly => (from.year - s.year) ~/ _step,
    };
    return math.max(0, est - 1);
  }

  /// All charge dates in the inclusive range [from]..[to].
  List<DateTime> paymentsBetween(DateTime from, DateTime to) {
    final a = dateOnly(from), b = dateOnly(to);
    final limit = _lastAllowed;
    final end = (limit != null && limit.isBefore(b)) ? limit : b;
    final result = <DateTime>[];
    if (end.isBefore(a) || end.isBefore(dateOnly(firstPayment))) return result;

    for (var k = _firstIndexNear(a); k < 100000; k++) {
      final d = _nth(k);
      if (d == null || d.isAfter(end)) break;
      if (!d.isBefore(a)) result.add(d);
    }
    return result;
  }

  bool isPaymentOn(DateTime day) => paymentsBetween(day, day).isNotEmpty;

  List<DateTime> paymentsInMonth(int year, int month) => paymentsBetween(
    DateTime(year, month, 1),
    DateTime(year, month, _daysInMonth(year, month)),
  );

  double amountInMonth(int year, int month) =>
      amount * paymentsInMonth(year, month).length;

  /// The next charge on or after [from], or `null` if there is none.
  DateTime? nextPaymentFrom(DateTime from) {
    final a = dateOnly(from);
    final limit = _lastAllowed;
    for (var k = _firstIndexNear(a); k < 100000; k++) {
      final d = _nth(k);
      if (d == null || (limit != null && d.isAfter(limit))) return null;
      if (!d.isBefore(a)) return d;
    }
    return null;
  }

  /// Number of charges from the start up to and including [until].
  int paymentsUntil(DateTime until) =>
      paymentsBetween(firstPayment, until).length;

  /// Normalised cost per month — used for forecasts and category split.
  double get monthlyEquivalent => switch (cycle) {
    BillingCycle.weekly => amount * 52 / 12 / _step,
    BillingCycle.monthly => amount / _step,
    BillingCycle.yearly => amount / 12 / _step,
    BillingCycle.oneTime => 0,
  };

  // ---- Serialisation --------------------------------------------------------

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency': currency,
    'cycle': cycle.name,
    'interval': interval,
    'firstPayment': firstPayment.millisecondsSinceEpoch,
    'endDate': endDate?.millisecondsSinceEpoch,
    'category': category.name,
    'status': status.name,
    'accentColor': accentColor,
    'icon': icon,
    'remindDaysBefore': remindDaysBefore,
    'notes': notes,
  };

  /// Reads both the current format and the pre-1.0 one (enum indexes,
  /// free-text `currencySymbol`, boolean `notifications`).
  /// Throws [FormatException] when required fields are missing or broken.
  factory Subscription.fromMap(Map map, {String fallbackCurrency = 'USD'}) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is String) {
        return values.firstWhere((v) => v.name == raw, orElse: () => fallback);
      }
      if (raw is int && raw >= 0 && raw < values.length) return values[raw];
      return fallback;
    }

    final id = map['id'], name = map['name'], amount = map['amount'];
    final first = map['firstPayment'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        amount is! num ||
        first is! int) {
      throw const FormatException('Invalid subscription record');
    }

    final currency =
        map['currency'] is String && Currency.isKnown(map['currency'] as String)
        ? map['currency'] as String
        : Currency.codeFromLegacySymbol(
            map['currencySymbol'] as String? ?? '',
            fallbackCurrency,
          );

    final int? remind;
    if (map.containsKey('remindDaysBefore')) {
      final r = map['remindDaysBefore'];
      remind = r is int && r >= 0 ? r : null;
    } else {
      remind = (map['notifications'] as bool? ?? false) ? 1 : null;
    }

    final end = map['endDate'];
    final interval = map['interval'];

    return Subscription(
      id: id,
      name: name,
      amount: amount.toDouble().abs(),
      currency: currency,
      cycle: pick(BillingCycle.values, map['cycle'], BillingCycle.monthly),
      interval: interval is int && interval > 0 ? interval : 1,
      firstPayment: DateTime.fromMillisecondsSinceEpoch(first),
      endDate: end is int ? DateTime.fromMillisecondsSinceEpoch(end) : null,
      category: pick(SubCategory.values, map['category'], SubCategory.other),
      status: pick(SubStatus.values, map['status'], SubStatus.active),
      accentColor: map['accentColor'] as int? ?? 0xFF34C759,
      icon: (map['icon'] as String?)?.trim().isNotEmpty == true
          ? (map['icon'] as String).trim()
          : '💳',
      remindDaysBefore: remind,
      notes: map['notes'] as String? ?? '',
    );
  }

  Subscription copyWith({
    String? id,
    String? name,
    double? amount,
    String? currency,
    BillingCycle? cycle,
    int? interval,
    DateTime? firstPayment,
    DateTime? Function()? endDate,
    SubCategory? category,
    SubStatus? status,
    int? accentColor,
    String? icon,
    int? Function()? remindDaysBefore,
    String? notes,
  }) => Subscription(
    id: id ?? this.id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    cycle: cycle ?? this.cycle,
    interval: interval ?? this.interval,
    firstPayment: firstPayment ?? this.firstPayment,
    endDate: endDate != null ? endDate() : this.endDate,
    category: category ?? this.category,
    status: status ?? this.status,
    accentColor: accentColor ?? this.accentColor,
    icon: icon ?? this.icon,
    remindDaysBefore: remindDaysBefore != null
        ? remindDaysBefore()
        : this.remindDaysBefore,
    notes: notes ?? this.notes,
  );
}
