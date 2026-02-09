import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static Future<SharedPreferences> _sp() async {
    return SharedPreferences.getInstance();
  }

  // ====== MARKET ROLE ======
  static const String _keyMarketRole = 'market_role'; // 'client' | 'pro'

  static Future<String> getMarketRole() async {
    final sp = await _sp();
    final v = (sp.getString(_keyMarketRole) ?? 'client').trim().toLowerCase();
    return (v == 'pro') ? 'pro' : 'client';
  }

  static Future<void> setMarketRole(String role) async {
    final sp = await _sp();
    final v = (role == 'pro') ? 'pro' : 'client';
    await sp.setString(_keyMarketRole, v);
  }

  // ====== ALIASES (COMPAT COM CÓDIGO ANTIGO) ======
  static Future<String> getCachedRole() => getMarketRole();
  static Future<void> setCachedRole(String role) => setMarketRole(role);

  // ====== AGENDA ======
  static const String _keyAgenda = 'agenda_items';

  static Future<List<Map<String, dynamic>>> getAgenda() async {
    final sp = await _sp();
    final raw = sp.getString(_keyAgenda);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return List<Map<String, dynamic>>.from(decoded);
    } catch (_) {
      return [];
    }
  }

  static Future<void> setAgenda(List<Map<String, dynamic>> items) async {
    final sp = await _sp();
    await sp.setString(_keyAgenda, jsonEncode(items));
  }

  static Future<void> clearAgenda() async {
    final sp = await _sp();
    await sp.remove(_keyAgenda);
  }
}
