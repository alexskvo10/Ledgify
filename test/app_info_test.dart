import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledgify/app_info.dart';

void main() {
  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*([0-9.]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m?.group(1), appVersion);
  });
}
