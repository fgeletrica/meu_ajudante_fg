import 'package:flutter/material.dart';
import '../services/auth/role_service.dart';

class DevRoleScreen extends StatefulWidget {
  const DevRoleScreen({super.key});

  @override
  State<DevRoleScreen> createState() => _DevRoleScreenState();
}

class _DevRoleScreenState extends State<DevRoleScreen> {
  String _role = 'client';

  Future<void> _load() async {
    _role = await RoleService.getRole();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = _role == 'pro';
    return Scaffold(
      appBar: AppBar(title: const Text('DEV: Role')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Role atual: $_role', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await RoleService.setPro(!isPro);
                await _load();
              },
              child: Text(isPro ? 'Trocar para CLIENT' : 'Trocar para PRO'),
            ),
          ],
        ),
      ),
    );
  }
}
