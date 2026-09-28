import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/storage.dart';
import 'data/sub_repository.dart';
import 'l10n/strings.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'state/settings_provider.dart';
import 'state/subs_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await openStorage();

  final settings = SettingsProvider();
  final subs = SubsProvider(SubRepository(), settings);
  runApp(LedgifyApp(settings: settings, subs: subs));
}

class LedgifyApp extends StatelessWidget {
  const LedgifyApp({super.key, required this.settings, required this.subs});

  final SettingsProvider settings;
  final SubsProvider subs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: subs),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Ledgify',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: settings.locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: settings.onboardingDone
                ? const HomeShell(key: ValueKey('home'))
                : const OnboardingScreen(key: ValueKey('onboarding')),
          ),
        ),
      ),
    );
  }
}
