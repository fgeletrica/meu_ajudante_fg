import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../routes/app_routes.dart';
import '../services/auth/role_resolver.dart';

/// Home = DECISOR.
/// Sempre decide baseado no RoleResolver (profiles.role).
/// Sem “cache-first” pra não cair errado como CLIENTE no relogin.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    if (_navigated) return;
    _navigated = true;

    final sb = Supabase.instance.client;

    // espera auth estabilizar (token/session)
    final started = DateTime.now();
    while (sb.auth.currentUser == null &&
        DateTime.now().difference(started).inMilliseconds < 2500) {
      await Future.delayed(const Duration(milliseconds: 120));
    }

    String role = 'client';
    try {
      role = await RoleResolver.resolveRole();
      role = (role == 'pro') ? 'pro' : 'client';
    } catch (_) {
      role = 'client';
    }

    if (!mounted) return;

    final dest = (role == 'pro') ? AppRoutes.homePro : AppRoutes.homeClient;

    Navigator.pushNamedAndRemoveUntil(
      context,
      dest,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
