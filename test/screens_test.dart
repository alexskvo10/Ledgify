// Renders every screen in both themes, both languages and two window sizes.
//
// * Always: fails on layout overflow or any exception while building screens.
// * With LEDGIFY_SCREENSHOTS=1: also writes PNGs to build/screens/ for a
//   visual review (Windows fonts are loaded so text looks like the real app).
@Tags(['screens'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ledgify/data/demo_data.dart';
import 'package:ledgify/data/sub_repository.dart';
import 'package:ledgify/main.dart';
import 'package:ledgify/models/subscription.dart';
import 'package:ledgify/state/settings_provider.dart';
import 'package:ledgify/state/subs_provider.dart';

final _shots = Platform.environment['LEDGIFY_SCREENSHOTS'] == '1';
final _now = DateTime(2026, 9, 28, 12);

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> paths) async {
    final loader = FontLoader(name);
    var any = false;
    for (final p in paths) {
      final f = File(p);
      if (!f.existsSync()) continue;
      any = true;
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    if (any) await loader.load();
  }

  const win = r'C:\Windows\Fonts\';
  await family('Segoe UI', [
    '${win}segoeui.ttf',
    '${win}seguisb.ttf',
    '${win}segoeuib.ttf',
  ]);
  await family('Segoe UI Emoji', ['${win}seguiemj.ttf']);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter';
  await family('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
}

void main() {
  late Box subsBox, settingsBox;
  var run = 0;

  setUpAll(() async {
    // A blinking cursor never lets pumpAndSettle finish.
    EditableText.debugDeterministicCursor = true;
    await initializeDateFormatting();
    if (_shots) await _loadFonts();
  });

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('ledgify_screens');
    Hive.init(dir.path);
  });

  // Fresh boxes per test. They are not closed: writes started inside the
  // widget tester's fake clock never complete, so close() would hang.
  setUp(() async {
    run++;
    subsBox = await Hive.openBox('subs_$run');
    settingsBox = await Hive.openBox('settings_$run');
  });

  Future<void> shot(
    WidgetTester tester,
    String name, {
    String dir = 'build/screens',
  }) async {
    await tester.pumpAndSettle();
    if (!_shots) return;
    final element = find.byType(MaterialApp).evaluate().first;
    await tester.runAsync(() async {
      final image = await captureImage(element);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<(SettingsProvider, SubsProvider)> boot(
    WidgetTester tester, {
    required String theme,
    required String lang,
    required Size size,
    bool onboarded = true,
    bool demo = true,
    bool stress = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await settingsBox.putAll({
        'themeMode': theme,
        'localeCode': lang,
        'baseCurrency': lang == 'ru' ? 'RUB' : 'USD',
        'onboarding_complete': onboarded,
        'monthly_budget': lang == 'ru' ? 15000 : 150,
      });
      if (demo) {
        final repo = SubRepository(subsBox);
        await repo.putAll(buildDemoData(_now));
        // A long name to catch ellipsis problems.
        if (stress) {
          await repo.put(
            Subscription(
              id: 'long',
              name: 'Very Long Subscription Name For Overflow Testing Purposes',
              amount: 123456.78,
              currency: 'KZT',
              firstPayment: DateTime(2026, 9, 12),
              category: SubCategory.finance,
              accentColor: 0xFFE5B800,
              icon: 'AB',
            ),
          );
        }
      }
    });
    final settings = SettingsProvider(settingsBox);
    final subs = SubsProvider(
      SubRepository(subsBox),
      settings,
      clock: () => _now,
    );
    await tester.pumpWidget(LedgifyApp(settings: settings, subs: subs));
    await tester.pumpAndSettle();
    return (settings, subs);
  }

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  // Clean demo-only shots for the README (written to docs/assets).
  testWidgets('readme screenshots', (tester) async {
    const assets = 'docs/assets';
    await boot(tester, theme: 'dark', lang: 'ru', size: desktop, stress: false);
    await shot(tester, 'screen-desktop', dir: assets);
  });

  testWidgets('readme phone screenshots', (tester) async {
    const assets = 'docs/assets';
    await boot(tester, theme: 'dark', lang: 'ru', size: phone, stress: false);
    await shot(tester, 'screen-calendar', dir: assets);
    await tester.tap(find.byIcon(Icons.donut_large_rounded));
    await shot(tester, 'screen-stats', dir: assets);
    await tester.tap(find.byIcon(Icons.calendar_month_rounded));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await shot(tester, 'screen-form', dir: assets);
  });

  for (final theme in ['dark', 'light']) {
    for (final lang in ['ru', 'en']) {
      for (final (sizeName, size) in [('phone', phone), ('desktop', desktop)]) {
        final tag = '${theme}_${lang}_$sizeName';

        testWidgets('main screens $tag', (tester) async {
          await boot(tester, theme: theme, lang: lang, size: size);
          await shot(tester, '${tag}_1_calendar');

          await tester.tap(find.byIcon(Icons.view_agenda_rounded));
          await shot(tester, '${tag}_2_list');

          await tester.tap(find.byIcon(Icons.donut_large_rounded));
          await shot(tester, '${tag}_3_stats');
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -700),
          );
          await shot(tester, '${tag}_3b_stats_scrolled');

          await tester.tap(find.byIcon(Icons.calendar_month_rounded));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
          await shot(tester, '${tag}_1b_calendar_next');
        });

        testWidgets('sheets and dialogs $tag', (tester) async {
          await boot(tester, theme: theme, lang: lang, size: size);

          // Detail card from the month list.
          await tester.tap(find.byIcon(Icons.view_agenda_rounded));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Spotify').first);
          await shot(tester, '${tag}_4_detail');
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();

          // Add form + validation errors.
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await shot(tester, '${tag}_5_form');
          await tester.tap(find.text(lang == 'ru' ? 'Добавить' : 'Add').last);
          await shot(tester, '${tag}_5b_form_errors');
        });

        testWidgets('settings $tag', (tester) async {
          await boot(tester, theme: theme, lang: lang, size: size);
          await tester.tap(find.byIcon(Icons.settings_outlined));
          await shot(tester, '${tag}_6_settings');
          await tester.tap(find.byIcon(Icons.currency_exchange_rounded));
          await shot(tester, '${tag}_7_rates');
        });

        testWidgets('empty and onboarding $tag', (tester) async {
          await boot(
            tester,
            theme: theme,
            lang: lang,
            size: size,
            onboarded: false,
            demo: false,
          );
          await shot(tester, '${tag}_8_onboarding');
          await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
          await shot(tester, '${tag}_8b_onboarding_last');
          await tester.tap(
            find.text(lang == 'ru' ? 'Начать с нуля' : 'Start from scratch'),
          );
          await shot(tester, '${tag}_9_empty_calendar');
          await tester.tap(find.byIcon(Icons.view_agenda_rounded));
          await shot(tester, '${tag}_9b_empty_list');
          await tester.tap(find.byIcon(Icons.donut_large_rounded));
          await shot(tester, '${tag}_9c_empty_stats');
        });
      }
    }
  }
}
