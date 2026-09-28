import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgify/data/backup.dart';
import 'package:ledgify/l10n/strings.dart';
import 'package:ledgify/models/currency.dart';
import 'package:ledgify/models/subscription.dart';

void main() {
  group('Rates', () {
    const r = Rates({'USD': 1, 'RUB': 90, 'EUR': 0.9});

    test('converts through USD', () {
      expect(r.convert(9, 'USD', 'RUB'), closeTo(810, 1e-9));
      expect(r.convert(900, 'RUB', 'EUR'), closeTo(9, 1e-9));
      expect(r.convert(5, 'EUR', 'EUR'), 5);
    });

    test(
      'missing or broken rates fall back to defaults, never divide by 0',
      () {
        const broken = Rates({'RUB': 0});
        expect(broken.convert(1, 'USD', 'RUB'), 1);
        expect(
          const Rates({}).convert(1, 'USD', 'EUR'),
          Currency.defaultRates['EUR'],
        );
      },
    );

    test('every known currency has a default rate', () {
      for (final c in Currency.all) {
        expect(Currency.defaultRates[c.code], isNotNull, reason: c.code);
      }
    });
  });

  group('parseAmount', () {
    test('accepts comma, dot and spaces', () {
      expect(S.parseAmount('1 234,50'), 1234.5);
      expect(S.parseAmount('9.99'), 9.99);
      expect(S.parseAmount(' 12 '), 12);
    });
    test('rejects junk', () {
      expect(S.parseAmount(''), isNull);
      expect(S.parseAmount('1.2.3'), isNull);
      expect(S.parseAmount('abc'), isNull);
    });
  });

  group('Backup', () {
    final subs = [
      Subscription(
        id: '1',
        name: 'Quote "test" \\ done',
        amount: 5,
        currency: 'EUR',
        firstPayment: DateTime(2026, 1, 1),
        notes: 'line1\nline2',
      ),
      Subscription(
        id: '2',
        name: 'Яндекс Плюс',
        amount: 399,
        currency: 'RUB',
        firstPayment: DateTime(2026, 3, 9),
        remindDaysBefore: 3,
      ),
    ];

    test('encode produces valid JSON that decodes to the same records', () {
      final text = Backup.encode(subs, baseCurrency: 'RUB');
      expect(() => jsonDecode(text), returnsNormally);
      final back = Backup.decode(text, fallbackCurrency: 'USD');
      expect(
        [for (final s in back) s.toMap()],
        [for (final s in subs) s.toMap()],
      );
    });

    test('accepts a bare list', () {
      final text = jsonEncode([for (final s in subs) s.toMap()]);
      expect(Backup.decode(text, fallbackCurrency: 'USD').length, 2);
    });

    test('rejects non-JSON, foreign JSON, newer formats and bad records', () {
      String reason(String t) {
        try {
          Backup.decode(t, fallbackCurrency: 'USD');
          return 'ok';
        } on FormatException catch (e) {
          return e.message;
        }
      }

      expect(reason('hello'), 'not-json');
      expect(reason('{"foo": 1}'), 'not-ledgify');
      expect(
        reason('{"app":"ledgify","format":99,"subscriptions":[]}'),
        'newer-format',
      );
      expect(reason('[1, 2]'), 'bad-record');
      expect(reason('[{"id":"a"}]'), 'Invalid subscription record');
    });

    test('file name', () {
      expect(
        Backup.fileName(DateTime(2026, 9, 8)),
        'ledgify-backup-2026-09-08.json',
      );
    });
  });
}
