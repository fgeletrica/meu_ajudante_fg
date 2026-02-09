import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CalcHistoryItem {
  final String id;
  final DateTime createdAt;

  final double powerW;
  final int voltageV;
  final double distanceM;

  final double currentA;
  final double cableMm2;
  final int breakerA;
  final double dropV;
  final double dropPerc;

  CalcHistoryItem({
    required this.id,
    required this.createdAt,
    required this.powerW,
    required this.voltageV,
    required this.distanceM,
    required this.currentA,
    required this.cableMm2,
    required this.breakerA,
    required this.dropV,
    required this.dropPerc,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'powerW': powerW,
        'voltageV': voltageV,
        'distanceM': distanceM,
        'currentA': currentA,
        'cableMm2': cableMm2,
        'breakerA': breakerA,
        'dropV': dropV,
        'dropPerc': dropPerc,
      };

  factory CalcHistoryItem.fromMap(Map<String, dynamic> m) => CalcHistoryItem(
        id: (m['id'] ?? '').toString(),
        createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        powerW: (m['powerW'] as num?)?.toDouble() ?? 0,
        voltageV: (m['voltageV'] as num?)?.toInt() ?? 0,
        distanceM: (m['distanceM'] as num?)?.toDouble() ?? 0,
        currentA: (m['currentA'] as num?)?.toDouble() ?? 0,
        cableMm2: (m['cableMm2'] as num?)?.toDouble() ?? 0,
        breakerA: (m['breakerA'] as num?)?.toInt() ?? 0,
        dropV: (m['dropV'] as num?)?.toDouble() ?? 0,
        dropPerc: (m['dropPerc'] as num?)?.toDouble() ?? 0,
      );
}

class CalcHistoryStore {
  static const _k = 'calc_history_v1';
  static const _max = 200;

  static Future<List<CalcHistoryItem>> list() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final arr = jsonDecode(raw) as List;
      final items = arr
          .whereType<Map>()
          .map((e) => CalcHistoryItem.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(CalcHistoryItem item) async {
    final items = await list();
    final next = [item, ...items];

    // remove duplicados por id
    final seen = <String>{};
    final dedup = <CalcHistoryItem>[];
    for (final it in next) {
      if (it.id.isEmpty) continue;
      if (seen.add(it.id)) dedup.add(it);
    }

    final trimmed = dedup.take(_max).toList();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(trimmed.map((e) => e.toMap()).toList()));
  }

  static Future<void> remove(String id) async {
    final items = await list();
    final kept = items.where((e) => e.id != id).toList();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(kept.map((e) => e.toMap()).toList()));
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_k);
  }
}
