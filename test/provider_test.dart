import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ledgify/data/demo_data.dart';
import 'package:ledgify/data/sub_repository.dart';
import 'package:ledgify/models/subscription.dart';
import 'package:ledgify/state/settings_provider.dart';
import 'package:ledgify/state/subs_provider.dart';

void main() {
  late Directory dir;
  late Box subsBox, settingsBox;
  final now = DateTime(2026, 9, 28, 14);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ledgify_test');
    Hive.init(dir.path);
    subsBox = await Hive.openBox('subscriptions');
    settingsBox = await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  (SettingsProvider, SubsProvider) make() {
    final settings = SettingsProvider(settingsBox);
    final subs = SubsProvider(
      SubRepository(subsBox),
      settings,
      clock: () => now,
    );
    return (settings, subs);
  }

  Subscription sub(
    String id,
    double amount,
    String cur, {
    SubStatus status = SubStatus.active,
    DateTime? first,
    int? remind,
    BillingCycle cycle = BillingCycle.monthly,
  }) => Subscription(
    id: id,
    name: id,
    amount: amount,
    currency: cur,
    cycle: cycle,
    firstPayment: first ?? DateTime(2026, 1, 10),
    status: status,
    remindDaysBefore: remind,
  );

  test('totals are converted to the base currency', () async {
    final (settings, subs) = make();
    await settings.setBaseCurrency('RUB');
    await settings.replaceRates({'USD': 1, 'RUB': 100}, now);
    await subs.save(sub('a', 10, 'USD'));
    await subs.save(sub('b', 500, 'RUB'));
    expect(subs.totalFor(DateTime(2026, 9)), closeTo(1500, 1e-9));
    expect(subs.monthlyForecast, closeTo(1500, 1e-9));
  });

  test('changing base currency keeps the budget value', () async {
    final (settings, _) = make();
    await settings.replaceRates({'USD': 1, 'RUB': 100}, now);
    await settings.setBaseCurrency('USD');
    await settings.setBudget(50);
    await settings.setBaseCurrency('RUB');
    expect(settings.budget, 5000);
  });

  test(
    'archived is ignored, canceled counts only until its end date',
    () async {
      final (_, subs) = make();
      await subs.save(sub('arch', 10, 'USD', status: SubStatus.archived));
      await subs.save(sub('live', 10, 'USD'));
      // Canceled today → closed today by save().
      await subs.save(sub('gone', 20, 'USD', status: SubStatus.canceled));
      final gone = subs.all.firstWhere((s) => s.id == 'gone');
      expect(gone.endDate, DateTime(2026, 9, 28));
      expect(subs.totalFor(DateTime(2026, 9)), 30);
      expect(subs.totalFor(DateTime(2026, 10)), 10);
      expect(subs.recurring.map((s) => s.id), ['live']);
    },
  );

  test('reactivating a canceled subscription clears its end date', () async {
    final (_, subs) = make();
    await subs.save(sub('x', 5, 'USD', status: SubStatus.canceled));
    final canceled = subs.all.single;
    await subs.save(canceled.copyWith(status: SubStatus.active));
    expect(subs.all.single.endDate, isNull);
  });

  test('finished trials become active on load', () async {
    await subsBox.put(
      't',
      sub(
        't',
        9,
        'USD',
        status: SubStatus.trial,
        first: DateTime(2026, 9, 20),
      ).toMap(),
    );
    await subsBox.put(
      'f',
      sub(
        'f',
        9,
        'USD',
        status: SubStatus.trial,
        first: DateTime(2026, 10, 20),
      ).toMap(),
    );
    final (_, subs) = make();
    final byId = {for (final s in subs.all) s.id: s.status};
    expect(byId['t'], SubStatus.active);
    expect(byId['f'], SubStatus.trial);
    expect(
      (subsBox.get('t') as Map)['status'],
      'active',
      reason: 'promotion is persisted',
    );
  });

  test('remove returns the item for undo; save restores it', () async {
    final (_, subs) = make();
    await subs.save(sub('a', 1, 'USD'));
    final removed = await subs.remove('a');
    expect(subs.isEmpty, isTrue);
    expect(subsBox.isEmpty, isTrue);
    await subs.save(removed!);
    expect(subs.all.single.id, 'a');
    expect(await subs.remove('missing'), isNull);
  });

  test('clearAll leaves storage empty (no demo resurrection)', () async {
    final (_, subs) = make();
    await subs.upsertAll(buildDemoData(now));
    expect(subs.all.length, 12);
    await subs.clearAll();
    final (_, again) = make();
    expect(again.isEmpty, isTrue);
  });

  test('reminders respect each window', () async {
    final (_, subs) = make();
    await subs.save(
      sub('tomorrow', 1, 'USD', first: DateTime(2026, 1, 29), remind: 1),
    );
    await subs.save(
      sub('in3', 1, 'USD', first: DateTime(2026, 1, 1), remind: 3),
    );
    await subs.save(sub('off', 1, 'USD', first: DateTime(2026, 1, 29)));
    await subs.save(
      sub('far', 1, 'USD', first: DateTime(2026, 1, 5), remind: 3),
    );
    // 1 Oct is 3 days after 28 Sep → inside the 3-day window.
    expect(subs.dueReminders.map((p) => p.sub.id), ['tomorrow', 'in3']);
  });

  test('mood compares with the yearly average', () {
    final (_, subs) = make();
    expect(subs.moodFor(0, 100), MonthMood.quiet);
    expect(subs.moodFor(200, 100), MonthMood.heavy);
    expect(subs.moodFor(50, 100), MonthMood.light);
    expect(subs.moodFor(100, 100), MonthMood.regular);
  });

  test('legacy settings are migrated', () async {
    await settingsBox.putAll({
      'themeMode': 'light',
      'defaultCurrency': '€',
      'localeCode': 'ru',
      'monthly_budget': 300,
      'onboarding_complete': true,
    });
    final (settings, _) = make();
    expect(settings.baseCurrency, 'EUR');
    expect(settings.locale.languageCode, 'ru');
    expect(settings.budget, 300);
    expect(settings.onboardingDone, isTrue);
  });

  test('corrupt record is skipped instead of crashing', () async {
    await subsBox.put('bad', {'name': 'broken'});
    await subsBox.put('good', sub('good', 1, 'USD').toMap());
    final (_, subs) = make();
    expect(subs.all.map((s) => s.id), ['good']);
  });
}
