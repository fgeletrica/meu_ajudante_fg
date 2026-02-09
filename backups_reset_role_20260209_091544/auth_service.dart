import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_store.dart';

class AuthService {
  static final SupabaseClient _sb = Supabase.instance.client;

  static User? get user => _sb.auth.currentUser;
  static Session? get session => _sb.auth.currentSession;

  static bool get isLoggedIn => session != null;

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _sb.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (res.session == null) {
      throw Exception('Falha ao entrar');
    }

    // sincroniza role real (profiles.role) e salva no LocalStore
    try {
      await getMyRole(); // getMyRole já faz setMarketRole internamente
    } catch (_) {}
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String role, // client | pro
    required String name,
    required String city,
    required String phone,
  }) async {
    final res = await _sb.auth.signUp(
      email: email,
      password: password,
    );

    final u = res.user;
    if (u == null) {
      throw Exception('Falha ao criar usuário');
    }

    // garante profile
    await _sb.from('profiles').upsert({
      'id': u.id,
      'role': role == 'pro' ? 'pro' : 'client',
      'name': name,
      'city': city,
      'phone': phone,
    });

    // salva role local
    try {
      await LocalStore.setMarketRole(role == 'pro' ? 'pro' : 'client');
    } catch (_) {}
  }

  static Future<void> signOut() async {
    try {
      await _sb.auth.signOut();
    } finally {
      // limpa role local pra não “vazar” pro próximo login
      try {
        // REMOVIDO: não limpar market_role no logout
      } catch (_) {}
    }
  }

  // =========================
  // ROLE (CLIENTE vs PRO)
  // =========================
  static Future<String> getMyRole() async {
    final u = user;
    if (u == null) return 'client';

    final res =
        await _sb.from('profiles').select('role').eq('id', u.id).maybeSingle();

    final raw = (res?['role'] ?? 'client').toString().trim();
    final role = (raw == 'pro') ? 'pro' : 'client';
    final normalized = role == 'pro' ? 'pro' : 'client';

    try {
      await LocalStore.setMarketRole(normalized);
    } catch (_) {}

    return normalized;
  }
}
