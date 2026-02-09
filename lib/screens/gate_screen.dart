import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import '../services/auth/role_resolver.dart';

class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _sb = Supabase.instance.client;
  StreamSubscription<AuthState>? _sub;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _boot();

    // qualquer mudanca de auth (login/logout) re-roda o gate
    _sub = _sb.auth.onAuthStateChange.listen((_) => _boot());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    if (!mounted) return;
    setState(() => _busy = true);

    // pequeno delay pra evitar corrida do Supabase preenchendo session/currentUser
    await Future.delayed(const Duration(milliseconds: 120));

    final session = _sb.auth.currentSession;
    final user = _sb.auth.currentUser;

    // SEM SESSAO => LOGIN
    if (session == null || user == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
      return;
    }

    // COM SESSAO => resolve role no server (com fallback no cache)
    String role = 'client';
    try {
      role = await RoleResolver.resolveRole();
    } catch (_) {
      role = 'client';
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      role == 'pro' ? AppRoutes.homePro : AppRoutes.homeClient,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1B2A),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
            : const SizedBox.shrink(),
      ),
    );
  }
}
