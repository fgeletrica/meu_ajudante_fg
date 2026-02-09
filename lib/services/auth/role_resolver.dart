import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local_store.dart';

class RoleResolver {
  static final SupabaseClient _sb = Supabase.instance.client;

  /// Fonte da verdade: public.profiles.role
  /// - Sempre tenta server
  /// - Cache é só fallback se estiver offline/erro
  static Future<String> resolveRole() async {
    // espera sessão aparecer (evita race do relogar)
    for (int i = 0; i < 10; i++) {
      if (_sb.auth.currentUser != null) break;
      await Future.delayed(const Duration(milliseconds: 120));
    }

    final u = _sb.auth.currentUser;
    if (u == null) {
      final cached = await LocalStore.getCachedRole();
      return (cached == 'pro') ? 'pro' : 'client';
    }

    // tenta buscar no server com retry
    for (int i = 0; i < 10; i++) {
      try {
        final res = await _sb
            .from('profiles')
            .select('role')
            .eq('id', u.id)
            .maybeSingle();

        final raw = (res?['role'] ?? '').toString().trim().toLowerCase();
        if (raw == 'pro' || raw == 'client') {
          await LocalStore.setCachedRole(raw);
          return raw;
        }
      } catch (_) {
        // segue retry
      }
      await Future.delayed(const Duration(milliseconds: 180));
    }

    // fallback cache
    final cached = await LocalStore.getCachedRole();
    return (cached == 'pro') ? 'pro' : 'client';
  }
}
