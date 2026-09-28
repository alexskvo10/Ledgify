import 'package:flutter_test/flutter_test.dart';
import 'package:ledgify/models/subscription.dart';

Subscription sub({
  BillingCycle cycle = BillingCycle.monthly,
  int interval = 1,
  required DateTime first,
  DateTime? end,
  SubStatus status = SubStatus.active,
  double amount = 10,
}) => Subscription(
  id: 'x',
  name: 'Test',
  amount: amount,
  cycle: cycle,
  interval: interval,
  firstPayment: first,
  endDate: end,
  status: status,
);

void main() {
  group('monthly', () {
    test('charges once a month on the anchor day', () {
      final s = sub(first: DateTime(2026, 1, 15));
      expect(s.paymentsInMonth(2026, 3), [DateTime(2026, 3, 15)]);
      expect(s.isPaymentOn(DateTime(2026, 3, 15)), isTrue);
      expect(s.isPaymentOn(DateTime(2026, 3, 16)), isFalse);
      expect(s.paymentsInMonth(2025, 12), isEmpty, reason: 'before start');
    });

    test('31st clamps to the last day of short months', () {
      final s = sub(first: DateTime(2026, 1, 31));
      expect(s.paymentsInMonth(2026, 2), [DateTime(2026, 2, 28)]);
      expect(s.paymentsInMonth(2028, 2), [DateTime(2028, 2, 29)]);
      expect(s.paymentsInMonth(2026, 4), [DateTime(2026, 4, 30)]);
      // …and returns to the 31st afterwards (no drift).
      expect(s.paymentsInMonth(2026, 5), [DateTime(2026, 5, 31)]);
    });

    test('every 3 months', () {
      final s = sub(first: DateTime(2026, 1, 10), interval: 3);
      final months = [
        for (var m = 1; m <= 12; m++)
          if (s.paymentsInMonth(2026, m).isNotEmpty) m,
      ];
      expect(months, [1, 4, 7, 10]);
      expect(s.monthlyEquivalent, closeTo(10 / 3, 1e-9));
    });

    test('far future stays exact and cheap', () {
      final s = sub(first: DateTime(2020, 5, 20));
      expect(s.paymentsInMonth(2090, 5), [DateTime(2090, 5, 20)]);
      expect(s.nextPaymentFrom(DateTime(2090, 5, 21)), DateTime(2090, 6, 20));
    });
  });

  group('weekly', () {
    test('every week and every 2 weeks', () {
      final w = sub(cycle: BillingCycle.weekly, first: DateTime(2026, 3, 2));
      expect(w.paymentsInMonth(2026, 3).length, 5); // 2, 9, 16, 23, 30
      final w2 = sub(
        cycle: BillingCycle.weekly,
        interval: 2,
        first: DateTime(2026, 3, 2),
      );
      expect(w2.paymentsInMonth(2026, 3), [
        DateTime(2026, 3, 2),
        DateTime(2026, 3, 16),
        DateTime(2026, 3, 30),
      ]);
    });

    test('daylight saving change does not shift the day', () {
      // Europe switches clocks on the last Sunday of March and October.
      final w = sub(cycle: BillingCycle.weekly, first: DateTime(2026, 3, 23));
      expect(w.isPaymentOn(DateTime(2026, 3, 30)), isTrue);
      expect(w.isPaymentOn(DateTime(2026, 11, 2)), isTrue);
    });
  });

  group('yearly', () {
    test('29 Feb falls back to 28 Feb in common years', () {
      final y = sub(cycle: BillingCycle.yearly, first: DateTime(2024, 2, 29));
      expect(y.paymentsInMonth(2025, 2), [DateTime(2025, 2, 28)]);
      expect(y.paymentsInMonth(2028, 2), [DateTime(2028, 2, 29)]);
      expect(y.monthlyEquivalent, closeTo(10 / 12, 1e-9));
    });

    test('every 2 years', () {
      final y = sub(
        cycle: BillingCycle.yearly,
        interval: 2,
        first: DateTime(2026, 6, 1),
      );
      expect(y.paymentsInMonth(2027, 6), isEmpty);
      expect(y.paymentsInMonth(2028, 6), [DateTime(2028, 6, 1)]);
    });
  });

  test('one-time charges once', () {
    final o = sub(cycle: BillingCycle.oneTime, first: DateTime(2026, 4, 9));
    expect(o.paymentsBetween(DateTime(2020), DateTime(2030)), [
      DateTime(2026, 4, 9),
    ]);
    expect(o.nextPaymentFrom(DateTime(2026, 4, 10)), isNull);
    expect(o.monthlyEquivalent, 0);
  });

  group('end date', () {
    test('no charges after the end date, past ones remain', () {
      final s = sub(
        first: DateTime(2026, 1, 5),
        end: DateTime(2026, 4, 20),
        status: SubStatus.canceled,
      );
      expect(s.paymentsInMonth(2026, 4), [DateTime(2026, 4, 5)]);
      expect(s.paymentsInMonth(2026, 5), isEmpty);
      expect(s.paymentsUntil(DateTime(2030)), 4);
      expect(s.nextPaymentFrom(DateTime(2026, 4, 6)), isNull);
    });

    test('legacy canceled without end date never charged', () {
      final s = sub(first: DateTime(2026, 1, 5), status: SubStatus.canceled);
      expect(s.paymentsUntil(DateTime(2030)), 0);
    });
  });

  test('nextPaymentFrom returns the same day when due today', () {
    final s = sub(first: DateTime(2026, 1, 15));
    expect(s.nextPaymentFrom(DateTime(2026, 9, 15, 18)), DateTime(2026, 9, 15));
    expect(s.nextPaymentFrom(DateTime(2026, 9, 16)), DateTime(2026, 10, 15));
  });

  group('serialisation', () {
    test('round trip keeps every field', () {
      final s = Subscription(
        id: 'a',
        name: 'Netflix',
        amount: 15.49,
        currency: 'EUR',
        cycle: BillingCycle.weekly,
        interval: 2,
        firstPayment: DateTime(2026, 2, 3),
        endDate: DateTime(2026, 8, 1),
        category: SubCategory.entertainment,
        status: SubStatus.canceled,
        accentColor: 0xFFE50914,
        icon: '🎬',
        remindDaysBefore: 3,
        notes: 'family plan',
      );
      final back = Subscription.fromMap(s.toMap());
      expect(back.toMap(), s.toMap());
    });

    test('reads pre-1.0 records (indexes, symbol, notifications)', () {
      final legacy = {
        'id': 'old',
        'name': 'Spotify',
        'amount': 10.99,
        'currencySymbol': '₽',
        'cycle': 2, // yearly
        'firstPayment': DateTime(2026, 1, 4).millisecondsSinceEpoch,
        'category': 0,
        'status': 1,
        'accentColor': 0xFF1DB954,
        'icon': '🎧',
        'notifications': true,
        'notes': '',
      };
      final s = Subscription.fromMap(legacy, fallbackCurrency: 'USD');
      expect(s.currency, 'RUB');
      expect(s.cycle, BillingCycle.yearly);
      expect(s.category, SubCategory.entertainment);
      expect(s.status, SubStatus.trial);
      expect(s.remindDaysBefore, 1);
      expect(s.interval, 1);
    });

    test('unknown legacy symbol falls back to the base currency', () {
      final s = Subscription.fromMap({
        'id': 'z',
        'name': 'X',
        'amount': 1,
        'currencySymbol': 'kr',
        'firstPayment': 0,
      }, fallbackCurrency: 'KZT');
      expect(s.currency, 'KZT');
    });

    test('broken record throws FormatException', () {
      expect(
        () => Subscription.fromMap({'name': 'no id'}),
        throwsFormatException,
      );
      expect(
        () => Subscription.fromMap({
          'id': 'a',
          'name': 'x',
          'amount': 'ten',
          'firstPayment': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
