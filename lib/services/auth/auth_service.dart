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

    // sincroniza role do banco (não trava UI)
    try {
      await getMyRole();
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
      data: {
        'role': (role == 'pro') ? 'pro' : 'client',
        'name': name,
        'city': city,
        'phone': phone,
      },
    );

    final u = res.user;
    if (u == null) {
      throw Exception('Falha ao criar usuario');
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
      await _sb.auth.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}
    // não apaga market_role aqui
  }

  // =========================
  // ROLE (CLIENTE vs PRO)
  // =========================
  static Future<String> getMyRole() async {
    // fallback: usa cache local (não rebaixa pra client por erro de rede)
    var cached = 'client';
    try {
      cached = await LocalStore.getMarketRole();
    } catch (_) {}

    final u = _sb.auth.currentUser;
    if (u == null) return cached;

    // 1) tenta metadata primeiro
    try {
      final m1 = (u.userMetadata ?? const {}) as Map;
      final m2 = (u.appMetadata ?? const {}) as Map;
      final r = (m1['role'] ?? m2['role'] ?? '').toString().trim().toLowerCase();
      if (r == 'pro' || r == 'client') {
        if (r != cached) {
          try { await LocalStore.setMarketRole(r); } catch (_) {}
        }
        return r;
      }
    } catch (_) {}

    // 2) fallback pro banco (profiles.role)
    try {
      final row = await _sb
          .from('profiles')
          .select('role')
          .eq('id', u.id)
          .maybeSingle();

      final r = (row?['role'] ?? '').toString().trim().toLowerCase();
      if (r == 'pro' || r == 'client') {
        if (r != cached) {
          try { await LocalStore.setMarketRole(r); } catch (_) {}
        }
        return r;
      }
    } catch (_) {
      // ignora: mantém cached
    }

    return cached;
  }
}
