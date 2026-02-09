import 'package:shared_preferences/shared_preferences.dart';

class RoleService {
  static const _kRoleKey = 'market_role'; // 'pro' | 'client'

  static Future<String> getRole() async {
    final sp = await SharedPreferences.getInstance();
    final r = (sp.getString(_kRoleKey) ?? 'client').trim().toLowerCase();
    return (r == 'pro') ? 'pro' : 'client';
  }

  /// TRAVA TEMP:
  /// - Só permite subir pra 'pro'
  /// - Qualquer tentativa de setar 'client' é ignorada
  static Future<void> setRole(String role) async {
    final r = role.trim().toLowerCase();
    if (r != 'pro') {
      // ignora downgrade por bug/botão/relog
      return;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRoleKey, 'pro');
  }

  /// TRAVA TEMP: setPro(false) não derruba mais.
  static Future<void> setPro(bool v) => setRole(v ? 'pro' : 'client');
}
