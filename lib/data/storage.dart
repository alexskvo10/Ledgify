import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Hive box names used by the app.
abstract final class Boxes {
  static const subscriptions = 'subscriptions';
  static const settings = 'settings';

  /// Written by pre-1.0 builds (a deletion log). No longer used; its file is
  /// removed during the storage move below.
  static const legacyHistory = 'payment_history';
}

/// Keys only Ledgify writes to its settings box — used to make sure a
/// `settings.hive` found in Documents is really ours before removing it.
const _ledgifySettingsKeys = {
  'onboarding_complete',
  'themeMode',
  'localeCode',
  'defaultCurrency',
  'baseCurrency',
  'monthly_budget',
};

/// Opens Hive in the app's private data folder.
///
/// Before 1.0 the boxes were created in the user's Documents folder (Hive's
/// default). On first start they are copied to the app folder; the old files
/// are removed only after the copies opened successfully, and a
/// `settings.hive` is removed only if it holds Ledgify's own keys (another
/// Hive app could use the same generic name).
Future<void> openStorage() async {
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}${Platform.pathSeparator}data');
  await dir.create(recursive: true);

  final legacy = await _copyLegacyBoxes(dir);
  Hive.init(dir.path);
  await Hive.openBox(Boxes.subscriptions);
  final settings = await Hive.openBox(Boxes.settings);

  if (legacy == null) return;
  final settingsAreOurs = settings.keys.any(_ledgifySettingsKeys.contains);
  if (legacy.copiedSettings && !settingsAreOurs) {
    await settings.clear(); // someone else's file: forget our copy of it
  }
  for (final name in [
    Boxes.subscriptions,
    Boxes.legacyHistory,
    if (legacy.copiedSettings && settingsAreOurs) Boxes.settings,
  ]) {
    for (final ext in ['hive', 'lock']) {
      final f = File('${legacy.docs}${Platform.pathSeparator}$name.$ext');
      try {
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('Could not remove legacy file ${f.path}: $e');
      }
    }
  }
}

typedef _Legacy = ({String docs, bool copiedSettings});

/// Copies pre-1.0 boxes from Documents into [target]. Runs only once: when
/// the new folder has no data yet and Documents has `subscriptions.hive`.
Future<_Legacy?> _copyLegacyBoxes(Directory target) async {
  final sep = Platform.pathSeparator;
  if (await File('${target.path}$sep${Boxes.subscriptions}.hive').exists()) {
    return null;
  }

  final String docs;
  try {
    docs = (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    return null;
  }
  final oldSubs = File('$docs$sep${Boxes.subscriptions}.hive');
  if (!await oldSubs.exists()) return null;

  await oldSubs.copy('${target.path}$sep${Boxes.subscriptions}.hive');
  final oldSettings = File('$docs$sep${Boxes.settings}.hive');
  final copiedSettings = await oldSettings.exists();
  if (copiedSettings) {
    await oldSettings.copy('${target.path}$sep${Boxes.settings}.hive');
  }
  return (docs: docs, copiedSettings: copiedSettings);
}
