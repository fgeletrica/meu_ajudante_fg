import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../routes/app_routes.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/role_resolver.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _checking = true;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();

    Supabase.instance.client.auth.onAuthStateChange.listen((_) async {
      if (!mounted) return;
      _navigated = false;
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    setState(() => _checking = true);

    if (!AuthService.isLoggedIn) {
      if (!mounted) return;
      setState(() => _checking = false);
      return;
    }

    // aquece o resolver (garante cache correto)
    try {
      await RoleResolver.resolveRole();
    } catch (_) {}

    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!AuthService.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return FutureBuilder<String>(
      future: RoleResolver.resolveRole(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (_navigated) return const Scaffold(body: SizedBox.shrink());
        _navigated = true;

        final role = (snap.data == 'pro') ? 'pro' : 'client';
        final dest = (role == 'pro') ? AppRoutes.homePro : AppRoutes.homeClient;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(context, dest, (_) => false);
        });

        return const Scaffold(body: SizedBox.shrink());
      },
    );
  }
}
