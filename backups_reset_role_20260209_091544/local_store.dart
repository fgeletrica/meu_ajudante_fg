import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static Future<SharedPreferences> _sp() async {
    return SharedPreferences.getInstance();
  }

  // ====== CHAVES ======
  static const String _keyAccountType =
      'account_type'; // 'eletrica' | 'industrial' (ou outro)
  static const String _keyMarketRole = 'market_role'; // 'client' | 'pro'
  static const String _keyAgenda = 'agenda_items'; // lista de itens em JSON

  // ====== ACCOUNT TYPE ======
  static Future<String> getAccountType({String fallback = 'eletrica'}) async {
    final sp = await _sp();
    return sp.getString(_keyAccountType) ?? fallback;
  }

  static Future<void> setAccountType(String type) async {
    final sp = await _sp();
    await sp.setString(_keyAccountType, type);
  }

  static Future<void> clearAccountType() async {
    final sp = await _sp();
    await sp.remove(_keyAccountType);
  }

  // ====== MARKET ROLE ======
  static Future<String> getMarketRole() async {
    final sp = await _sp();
    final v = (sp.getString(_keyMarketRole) ?? 'client').trim().toLowerCase();
    return (v == 'pro') ? 'pro' : 'client';
  }

  static Future<void> setMarketRole(String role) async {
    final sp = await _sp();

    final cur = (sp.getString(_keyMarketRole) ?? 'client').trim().toLowerCase();
    final next = role.trim().toLowerCase();

    // REGRA: se já é PRO localmente, não deixa cair pra client por bug/fluxo
    if (cur == 'pro') {
      await sp.setString(_keyMarketRole, 'pro');
      return;
    }

    await sp.setString(_keyMarketRole, (next == 'pro') ? 'pro' : 'client');
  }

  static Future<void> clearMarketRole() async {
    // NÃO limpar role no logout. Role é parte do perfil/cache.
    return;
  }

  // ====== AGENDA (JSON) ======
  static Future<List<Map<String, dynamic>>> getAgenda() async {
    final sp = await _sp();
    final raw = sp.getString(_keyAgenda);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> setAgenda(List<dynamic> items) async {
    final sp = await _sp();
    try {
      final norm =
          items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await sp.setString(_keyAgenda, jsonEncode(norm));
    } catch (_) {
      await sp.setString(_keyAgenda, jsonEncode([]));
    }
  }

  static Future<void> clearAgenda() async {
    final sp = await _sp();
    await sp.remove(_keyAgenda);
  }
}
