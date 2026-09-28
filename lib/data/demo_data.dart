import 'package:uuid/uuid.dart';

import '../models/subscription.dart';

/// Sample subscriptions, added only when the user asks for them
/// (onboarding or Settings → Data). Dates are relative to [now] so charges
/// show up in the current month.
List<Subscription> buildDemoData(DateTime now) {
  const uuid = Uuid();
  DateTime day(int d, [int monthShift = 0]) =>
      DateTime(now.year, now.month + monthShift, d);

  Subscription s(
    String name,
    double amount,
    String currency,
    DateTime first,
    SubCategory category,
    int color,
    String icon, {
    BillingCycle cycle = BillingCycle.monthly,
    int interval = 1,
    SubStatus status = SubStatus.active,
    int? remind = 1,
    DateTime? end,
  }) => Subscription(
    id: uuid.v4(),
    name: name,
    amount: amount,
    currency: currency,
    cycle: cycle,
    interval: interval,
    firstPayment: first,
    endDate: end,
    category: category,
    status: status,
    accentColor: color,
    icon: icon,
    remindDaysBefore: remind,
  );

  return [
    s(
      'Spotify',
      10.99,
      'USD',
      day(4, -8),
      SubCategory.entertainment,
      0xFF1DB954,
      '🎧',
    ),
    s(
      'Netflix',
      15.49,
      'USD',
      day(12, -14),
      SubCategory.entertainment,
      0xFFE50914,
      '🎬',
    ),
    s(
      'Яндекс Плюс',
      399,
      'RUB',
      day(9, -5),
      SubCategory.entertainment,
      0xFFFC3F1D,
      '⭐',
    ),
    s(
      'Duolingo',
      6.99,
      'USD',
      day(8, -3),
      SubCategory.education,
      0xFF58CC02,
      '🦉',
      remind: null,
    ),
    s(
      'iCloud+',
      2.99,
      'USD',
      day(2, -20),
      SubCategory.utilities,
      0xFF3693F3,
      '☁️',
      remind: null,
    ),
    s(
      'ChatGPT Plus',
      20,
      'USD',
      day(22, -6),
      SubCategory.productivity,
      0xFF10A37F,
      '🤖',
    ),
    s(
      'Notion',
      8,
      'USD',
      day(15, -10),
      SubCategory.productivity,
      0xFF37352F,
      '📝',
    ),
    s(
      'Adobe CC',
      599.88,
      'USD',
      day(6, -11),
      SubCategory.productivity,
      0xFFDA1F26,
      '🎨',
      cycle: BillingCycle.yearly,
      remind: 7,
    ),
    s(
      'Спортзал',
      3500,
      'RUB',
      day(1, -2),
      SubCategory.health,
      0xFF30B94D,
      '🏋️',
      interval: 3,
      remind: 3,
    ),
    s(
      'Мобильная связь',
      650,
      'RUB',
      day(18, -30),
      SubCategory.utilities,
      0xFF8E8E93,
      '📱',
      remind: null,
    ),
    s(
      'Disney+',
      9.99,
      'USD',
      DateTime(now.year, now.month, now.day + 10),
      SubCategory.entertainment,
      0xFF113CCF,
      '🏰',
      status: SubStatus.trial,
      remind: 3,
    ),
    s(
      'Xbox Game Pass',
      16.99,
      'USD',
      day(20, -9),
      SubCategory.entertainment,
      0xFF107C10,
      '🎮',
      status: SubStatus.canceled,
      end: day(20, -2),
      remind: null,
    ),
  ];
}
