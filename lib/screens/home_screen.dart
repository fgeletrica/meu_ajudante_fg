import 'package:flutter/material.dart';
import '../services/auth/role_service.dart';

import 'home_pro_screen.dart';
import 'home_client_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: RoleService.getRole(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snap.data!;
        if (role == 'pro') return const HomeProScreen();
        return const HomeClientScreen();
      },
    );
  }
}
