import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/app_mode_store.dart';
import '../services/auth/auth_service.dart';

import 'gate_screen.dart';
import 'home_pro_screen.dart';
import 'industrial_home_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  Future<void> _go(BuildContext context, String mode) async {
    await AppModeStore.setMode(mode);
    if (!context.mounted) return;

    // Industrial tem home própria
    if (mode == 'ind') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IndustrialHomeScreen()),
      );
      return;
    }

    // Residencial: volta pra home CERTA conforme ROLE (pro vs client)
    final role = await AuthService.getMyRole();
    if (!context.mounted) return;

    final next = (role == 'pro') ? const HomeProScreen() : const GateScreen();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.gold.withOpacity(.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.9),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _card({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? rightTag,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border.withOpacity(.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withOpacity(.35)),
              ),
              child: Icon(icon, color: AppTheme.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (rightTag != null) rightTag,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(.7)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text('Escolha o modo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Você quer usar o app em qual modo?',
              style: TextStyle(
                color: Colors.white.withOpacity(.85),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _card(
              context: context,
              icon: Icons.home_outlined,
              title: 'Residencial',
              subtitle: 'Cálculo, orçamentos e materiais do dia a dia.',
              onTap: () => _go(context, 'res'),
            ),
            const SizedBox(height: 12),
            _card(
              context: context,
              icon: Icons.factory_outlined,
              title: 'Industrial (EM DESENVOLVIMENTO)',
              subtitle:
                  'Você já pode testar, mas está em construção e melhorias.',
              rightTag: _badge('EM DESENVOLVIMENTO'),
              onTap: () => _go(context, 'ind'),
            ),
            const Spacer(),
            Text(
              'Dá pra trocar depois dentro do app.',
              style: TextStyle(color: Colors.white.withOpacity(.6)),
            ),
          ],
        ),
      ),
    );
  }
}
