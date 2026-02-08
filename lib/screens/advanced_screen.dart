import 'package:flutter/material.dart';
import 'package:meu_ajudante_fg/routes/app_routes.dart';
import '../core/app_theme.dart';
import '../services/app_mode_store.dart';
import 'gate_screen.dart';

class AdvancedScreen extends StatelessWidget {
  const AdvancedScreen({super.key});

  Future<void> _enterIndustrial(BuildContext context) async {
    await AppModeStore.setMode('ind');
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: const Text('Avançado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.gold.withOpacity(.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(.12),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppTheme.gold.withOpacity(.35)),
                        ),
                        child: Icon(Icons.construction, color: AppTheme.gold),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Modo Industrial (BETA)',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '🚧 EM DESENVOLVIMENTO',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.9),
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esse modo ainda está sendo construído. Pode ter telas incompletas e mudanças.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.75),
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Você pode usar mesmo assim para testar:',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.75),
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _bullet('Linha Parou / histórico / exportação'),
                  _bullet('Checklists & LOTO'),
                  _bullet('Base de falhas recorrentes'),
                  _bullet('Diagnóstico por sintoma'),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _enterIndustrial(context),
                icon: const Icon(Icons.factory_outlined),
                label: const Text('Entrar no Industrial (BETA)'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Dica: o foco principal agora é o modo Residencial.',
              style: TextStyle(
                  color: Colors.white.withOpacity(.55),
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bullet(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  color: Colors.white.withOpacity(.85),
                  fontWeight: FontWeight.w900)),
          Expanded(
              child: Text(t,
                  style: TextStyle(
                      color: Colors.white.withOpacity(.75),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
