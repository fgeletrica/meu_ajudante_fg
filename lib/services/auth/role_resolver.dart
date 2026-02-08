import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../local_store.dart';

class RoleResolver {
  static final _sb = Supabase.instance.client;

  /// Fonte de verdade: public.profiles.role  ('pro' | 'client')
  /// - Server FIRST
  /// - Retry curto pra evitar corrida pós-login
  /// - Só usa cache se não conseguir ler do server
  static Future<String> resolveRole() async {
    // espera sessão aparecer (relogin costuma dar currentUser null por alguns ms)
    for (int i = 0; i < 8; i++) {
      final u = _sb.auth.currentUser;
      if (u != null) break;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    final u = _sb.auth.currentUser;
    if (u == null) {
      // sem sessão: tenta cache, senão client
      try {
        final cached = await LocalStore.getMarketRole();
        return (cached == 'pro') ? 'pro' : 'client';
      } catch (_) {
        return 'client';
      }
    }

    // tenta buscar role no profiles com retry (evita race / RLS / refresh)
    for (int i = 0; i < 12; i++) {
      try {
        final Map<String, dynamic>? res = await _sb
            .from('profiles')
            .select('role')
            .eq('id', u.id)
            .maybeSingle();

        final raw = (res?['role'] ?? '').toString().trim().toLowerCase();

        if (raw == 'pro' || raw == 'client') {
          try {
            await LocalStore.setMarketRole(raw);
          } catch (_) {}
          return raw;
        }
      } catch (_) {
        // ignora e tenta de novo
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    // fallback: cache
    try {
      final cached = await LocalStore.getMarketRole();
      return (cached == 'pro') ? 'pro' : 'client';
    } catch (_) {
      return 'client';
    }
  }
}
