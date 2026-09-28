import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/subscription.dart';
import 'storage.dart';

/// Thin wrapper around the Hive box that persists subscriptions.
///
/// Each subscription is a primitive `Map` keyed by its id, so there is no
/// generated TypeAdapter to maintain and it behaves the same on every OS.
class SubRepository {
  SubRepository([Box? box]) : _box = box ?? Hive.box(Boxes.subscriptions);

  final Box _box;

  /// Loads every record; a broken record is skipped instead of crashing
  /// the whole app.
  List<Subscription> getAll({required String fallbackCurrency}) {
    final result = <Subscription>[];
    for (final raw in _box.values) {
      try {
        result.add(
          Subscription.fromMap(raw as Map, fallbackCurrency: fallbackCurrency),
        );
      } catch (e) {
        debugPrint('Skipping unreadable subscription: $e');
      }
    }
    return result;
  }

  Future<void> put(Subscription sub) => _box.put(sub.id, sub.toMap());

  Future<void> putAll(Iterable<Subscription> subs) =>
      _box.putAll({for (final s in subs) s.id: s.toMap()});

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();
}
