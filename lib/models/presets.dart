import 'subscription.dart';

/// A popular service the add form can pre-fill (name, icon, colour, category).
/// Prices differ per country, so the amount is left to the user.
class ServicePreset {
  const ServicePreset(
    this.name,
    this.icon,
    this.color,
    this.category, {
    this.cycle = BillingCycle.monthly,
  });

  final String name;
  final String icon;
  final int color;
  final SubCategory category;
  final BillingCycle cycle;

  static const all = <ServicePreset>[
    ServicePreset('Netflix', '🎬', 0xFFE50914, SubCategory.entertainment),
    ServicePreset('Spotify', '🎧', 0xFF1DB954, SubCategory.entertainment),
    ServicePreset(
      'YouTube Premium',
      '▶️',
      0xFFFF0000,
      SubCategory.entertainment,
    ),
    ServicePreset('Яндекс Плюс', '⭐', 0xFFFC3F1D, SubCategory.entertainment),
    ServicePreset('Кинопоиск', '🍿', 0xFFFF6600, SubCategory.entertainment),
    ServicePreset('Apple One', '🍎', 0xFF555555, SubCategory.lifestyle),
    ServicePreset('iCloud+', '☁️', 0xFF3693F3, SubCategory.utilities),
    ServicePreset('Google One', '💾', 0xFF4285F4, SubCategory.utilities),
    ServicePreset('ChatGPT Plus', '🤖', 0xFF10A37F, SubCategory.productivity),
    ServicePreset('Claude Pro', '✳️', 0xFFD97757, SubCategory.productivity),
    ServicePreset('Notion', '📝', 0xFF37352F, SubCategory.productivity),
    ServicePreset(
      'Microsoft 365',
      '📊',
      0xFF0078D4,
      SubCategory.productivity,
      cycle: BillingCycle.yearly,
    ),
    ServicePreset('Adobe CC', '🎨', 0xFFDA1F26, SubCategory.productivity),
    ServicePreset('Telegram Premium', '✈️', 0xFF2AABEE, SubCategory.lifestyle),
    ServicePreset('Duolingo', '🦉', 0xFF58CC02, SubCategory.education),
    ServicePreset(
      'Xbox Game Pass',
      '🎮',
      0xFF107C10,
      SubCategory.entertainment,
    ),
    ServicePreset(
      'PlayStation Plus',
      '🕹️',
      0xFF003791,
      SubCategory.entertainment,
    ),
    ServicePreset('Спортзал', '🏋️', 0xFF30B94D, SubCategory.health),
    ServicePreset('Мобильная связь', '📱', 0xFF8E8E93, SubCategory.utilities),
    ServicePreset('Интернет', '🌐', 0xFF0A84FF, SubCategory.utilities),
  ];
}
