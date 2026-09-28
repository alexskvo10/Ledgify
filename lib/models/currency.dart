/// A currency the app knows how to display and convert.
class Currency {
  const Currency(this.code, this.symbol, {this.decimals = 2});

  /// ISO 4217 code — the stable id stored on disk.
  final String code;
  final String symbol;
  final int decimals;

  static const all = <Currency>[
    Currency('USD', r'$'),
    Currency('EUR', '€'),
    Currency('RUB', '₽'),
    Currency('GBP', '£'),
    Currency('KZT', '₸'),
    Currency('UAH', '₴'),
    Currency('BYN', 'Br'),
    Currency('TRY', '₺'),
    Currency('GEL', '₾'),
    Currency('AMD', '֏', decimals: 0),
    Currency('PLN', 'zł'),
    Currency('CHF', 'Fr'),
    Currency('CNY', '¥'),
    Currency('JPY', '¥', decimals: 0),
    Currency('INR', '₹'),
  ];

  static final _byCode = {for (final c in all) c.code: c};

  static Currency of(String code) => _byCode[code] ?? all.first;

  static bool isKnown(String code) => _byCode.containsKey(code);

  /// Maps a legacy free-text symbol (stored before 1.0) to a code.
  static String codeFromLegacySymbol(String symbol, String fallback) {
    final s = symbol.trim();
    if (isKnown(s.toUpperCase())) return s.toUpperCase();
    return switch (s) {
      r'$' => 'USD',
      '€' => 'EUR',
      '₽' || 'р' || 'руб' || 'руб.' => 'RUB',
      '£' => 'GBP',
      '₸' => 'KZT',
      '₴' => 'UAH',
      '₺' => 'TRY',
      '₾' => 'GEL',
      '₹' => 'INR',
      _ => fallback,
    };
  }

  /// Approximate units per 1 USD, used until the user loads real rates.
  /// They only have to be in the right ballpark; the settings screen says so.
  static const defaultRates = <String, double>{
    'USD': 1,
    'EUR': 0.92,
    'RUB': 90,
    'GBP': 0.78,
    'KZT': 480,
    'UAH': 41,
    'BYN': 3.3,
    'TRY': 34,
    'GEL': 2.7,
    'AMD': 390,
    'PLN': 4.0,
    'CHF': 0.88,
    'CNY': 7.2,
    'JPY': 150,
    'INR': 84,
  };
}

/// Converts between currencies using "units per 1 USD" rates.
class Rates {
  const Rates(this.perUsd);

  final Map<String, double> perUsd;

  double _rate(String code) {
    final r = perUsd[code] ?? Currency.defaultRates[code];
    return (r == null || r <= 0) ? 1 : r;
  }

  double convert(double amount, String from, String to) {
    if (from == to) return amount;
    return amount / _rate(from) * _rate(to);
  }
}
