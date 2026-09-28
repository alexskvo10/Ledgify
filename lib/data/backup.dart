import 'dart:convert';

import '../models/subscription.dart';

/// Versioned JSON backup format.
///
/// ```json
/// { "app": "ledgify", "format": 1, "exportedAt": "2026-09-28T12:00:00.000",
///   "baseCurrency": "RUB", "subscriptions": [ { ...Subscription.toMap } ] }
/// ```
abstract final class Backup {
  static const formatVersion = 1;

  static String encode(
    List<Subscription> subs, {
    required String baseCurrency,
  }) => const JsonEncoder.withIndent('  ').convert({
    'app': 'ledgify',
    'format': formatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'baseCurrency': baseCurrency,
    'subscriptions': [for (final s in subs) s.toMap()],
  });

  /// Parses a backup. Accepts the object above or a bare list of records
  /// (what pre-1.0 "export" produced when it was valid JSON).
  /// Throws [FormatException] with a short reason when the text is unusable.
  static List<Subscription> decode(
    String text, {
    required String fallbackCurrency,
  }) {
    final Object? data;
    try {
      data = jsonDecode(text.trim());
    } on FormatException {
      throw const FormatException('not-json');
    }

    final Object? list;
    if (data is Map) {
      if (data['app'] != 'ledgify') throw const FormatException('not-ledgify');
      final format = data['format'];
      if (format is int && format > formatVersion) {
        throw const FormatException('newer-format');
      }
      list = data['subscriptions'];
    } else {
      list = data;
    }
    if (list is! List) throw const FormatException('not-ledgify');

    final result = <Subscription>[];
    for (final item in list) {
      if (item is! Map) throw const FormatException('bad-record');
      result.add(
        Subscription.fromMap(item, fallbackCurrency: fallbackCurrency),
      );
    }
    return result;
  }

  /// `ledgify-backup-2026-09-28.json`
  static String fileName(DateTime now) =>
      'ledgify-backup-${now.year}-${_two(now.month)}-${_two(now.day)}.json';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
