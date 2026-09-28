import 'dart:convert';
import 'dart:io';

import '../models/currency.dart';

/// Downloads "units per 1 USD" rates from open.er-api.com (free, no key).
/// Called only when the user taps "Update rates".
Future<Map<String, double>> fetchRates() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await client
        .getUrl(Uri.parse('https://open.er-api.com/v6/latest/USD'))
        .timeout(const Duration(seconds: 10));
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    final rates = json is Map ? json['rates'] : null;
    if (json is! Map || json['result'] != 'success' || rates is! Map) {
      throw const FormatException('Unexpected response');
    }
    final result = <String, double>{};
    for (final c in Currency.all) {
      final v = rates[c.code];
      if (v is num && v > 0) result[c.code] = v.toDouble();
    }
    if (result.length < 2) throw const FormatException('No usable rates');
    result['USD'] = 1;
    return result;
  } finally {
    client.close(force: true);
  }
}
