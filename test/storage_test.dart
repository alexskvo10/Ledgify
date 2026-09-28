// The one-time move of pre-1.0 Hive files out of the Documents folder.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:ledgify/data/storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePaths extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePaths(this.docs, this.support);
  final String docs, support;

  @override
  Future<String?> getApplicationDocumentsPath() async => docs;
  @override
  Future<String?> getApplicationSupportPath() async => support;
}

void main() {
  late Directory root, docs, support;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ledgify_storage');
    docs = await Directory('${root.path}/docs').create();
    support = await Directory('${root.path}/support').create();
    PathProviderPlatform.instance = _FakePaths(docs.path, support.path);
  });

  tearDown(() async {
    await Hive.close();
    await root.delete(recursive: true);
  });

  /// Writes real Hive files into Documents the way pre-1.0 builds did.
  Future<void> legacy(Map<String, Map<String, Object>> boxes) async {
    Hive.init(docs.path);
    for (final e in boxes.entries) {
      final b = await Hive.openBox(e.key);
      await b.putAll(e.value);
    }
    await Hive.close();
  }

  bool inDocs(String f) => File('${docs.path}/$f').existsSync();

  test('moves Ledgify boxes and removes the originals', () async {
    await legacy({
      'subscriptions': {
        'a': {'id': 'a'},
      },
      'settings': {'themeMode': 'light'},
      'payment_history': {'x': 1},
    });
    await openStorage();
    expect(Hive.box(Boxes.subscriptions).get('a'), {'id': 'a'});
    expect(Hive.box(Boxes.settings).get('themeMode'), 'light');
    expect(inDocs('subscriptions.hive'), isFalse);
    expect(inDocs('settings.hive'), isFalse);
    expect(inDocs('payment_history.hive'), isFalse);
    expect(
      File('${support.path}/data/subscriptions.hive').existsSync(),
      isTrue,
    );
  });

  test("leaves another app's settings.hive alone", () async {
    await legacy({
      'subscriptions': {
        'a': {'id': 'a'},
      },
      'settings': {'volume': 7},
    });
    await openStorage();
    expect(inDocs('settings.hive'), isTrue, reason: 'not ours');
    expect(Hive.box(Boxes.settings).isEmpty, isTrue, reason: 'copy discarded');
    expect(inDocs('subscriptions.hive'), isFalse);
  });

  test('does nothing without legacy data or once migrated', () async {
    await legacy({
      'settings': {'themeMode': 'dark'},
    });
    await openStorage();
    expect(
      inDocs('settings.hive'),
      isTrue,
      reason: 'no subscriptions.hive → not a Ledgify install',
    );
    expect(Hive.box(Boxes.settings).isEmpty, isTrue);
  });
}
