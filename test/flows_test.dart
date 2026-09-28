// End-to-end user flows driven through the real widgets.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ledgify/data/backup.dart';
import 'package:ledgify/data/demo_data.dart';
import 'package:ledgify/data/sub_repository.dart';
import 'package:ledgify/main.dart';
import 'package:ledgify/models/subscription.dart';
import 'package:ledgify/state/settings_provider.dart';
import 'package:ledgify/state/subs_provider.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  late Box subsBox, settingsBox;
  var run = 0;
  String clipboard = '';

  setUpAll(() async {
    EditableText.debugDeterministicCursor = true;
    await initializeDateFormatting();
    Hive.init((await Directory.systemTemp.createTemp('ledgify_flows')).path);
  });

  setUp(() async {
    run++;
    subsBox = await Hive.openBox('subs_$run');
    settingsBox = await Hive.openBox('settings_$run');
    clipboard = '';
  });

  Future<SubsProvider> boot(WidgetTester tester, {bool demo = false}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      },
    );
    await tester.runAsync(() async {
      await settingsBox.putAll({
        'localeCode': 'en',
        'baseCurrency': 'USD',
        'onboarding_complete': true,
      });
      if (demo) await SubRepository(subsBox).putAll(buildDemoData(_now));
    });
    final settings = SettingsProvider(settingsBox);
    final subs = SubsProvider(
      SubRepository(subsBox),
      settings,
      clock: () => _now,
    );
    await tester.pumpWidget(LedgifyApp(settings: settings, subs: subs));
    await tester.pumpAndSettle();
    return subs;
  }

  /// Lets real disk I/O (Hive) finish — the widget tester's fake clock
  /// doesn't advance it — then settles the UI.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 150)),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets('add a subscription through the form', (tester) async {
    final subs = await boot(tester);
    await tester.tap(find.text('Add subscription'));
    await tester.pumpAndSettle();

    // Validation blocks an empty form.
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(subs.isEmpty, isTrue);

    // Preset fills name/icon/colour; then amount + quarterly interval.
    await tester.tap(find.text('Netflix'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '15,49');
    await tester.ensureVisible(find.byTooltip('+'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('+')); // interval 2
    await tester.pump();
    await tester.tap(find.byTooltip('+')); // interval 3
    await tester.pump();
    expect(find.text('Every 3 months'), findsOneWidget);
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    final s = subs.all.single;
    expect(s.name, 'Netflix');
    expect(s.amount, 15.49);
    expect(s.interval, 3);
    expect(s.currency, 'USD');
    expect(find.text('“Netflix” added'), findsOneWidget);
  });

  testWidgets('closing a dirty form asks before discarding', (tester) async {
    final subs = await boot(tester);
    await tester.tap(find.text('Add subscription'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Gym');
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('New subscription'), findsNothing);
    expect(subs.isEmpty, isTrue);
  });

  testWidgets('delete from the detail card and undo', (tester) async {
    final subs = await boot(tester, demo: true);
    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spotify').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await settle(tester);
    expect(subs.all.any((s) => s.name == 'Spotify'), isFalse);
    expect(find.text('“Spotify” deleted'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(subs.all.any((s) => s.name == 'Spotify'), isTrue);
  });

  testWidgets('archive hides from totals and the default list', (tester) async {
    final subs = await boot(tester, demo: true);
    final before = subs.monthlyForecast;
    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spotify').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Archive'));
    await settle(tester);
    expect(subs.monthlyForecast, closeTo(before - 10.99, 1e-6));
    expect(find.text('Spotify'), findsNothing);
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Spotify'), findsOneWidget);
  });

  testWidgets('search matches name, category and notes', (tester) async {
    await boot(tester, demo: true);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'educ');
    await tester.pumpAndSettle();
    expect(find.text('Duolingo'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing found'), findsOneWidget);
  });

  testWidgets('budget can be set from statistics', (tester) async {
    await boot(tester, demo: true);
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set budget'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final settings = tester
        .element(find.byType(MaterialApp))
        .findAncestorWidgetOfExactType<LedgifyApp>()!
        .settings;
    expect(settings.budget, 250);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('export then import through the clipboard', (tester) async {
    final subs = await boot(tester, demo: true);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export backup'));
    await settle(tester);
    expect(Backup.decode(clipboard, fallbackCurrency: 'USD').length, 12);

    // Wipe, then restore from the clipboard.
    await tester.tap(find.text('Delete all subscriptions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all'));
    await settle(tester);
    expect(subs.isEmpty, isTrue);

    await tester.tap(find.text('Import from clipboard'));
    await settle(tester);
    expect(subs.all.length, 12);
    expect(find.text('Imported 12 subscriptions'), findsOneWidget);

    // Garbage in the clipboard is rejected with a clear message.
    clipboard = 'not a backup';
    await tester.tap(find.text('Import from clipboard'));
    await tester.pumpAndSettle();
    expect(find.text('The clipboard does not contain JSON'), findsOneWidget);
  });

  testWidgets('canceling in the form stops future charges', (tester) async {
    final subs = await boot(tester);
    await tester.runAsync(
      () => subs.save(
        Subscription(
          id: 'x',
          name: 'Gym',
          amount: 30,
          firstPayment: DateTime(2026, 1, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Subscriptions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canceled').last); // the chip in the form
    await tester.pumpAndSettle();
    expect(find.text('Canceled on'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final gym = subs.all.single;
    expect(gym.status, SubStatus.canceled);
    expect(gym.endDate, DateTime(2026, 9, 28));
    expect(subs.totalFor(DateTime(2026, 9)), 30);
    expect(subs.totalFor(DateTime(2026, 10)), 0);
  });
}
