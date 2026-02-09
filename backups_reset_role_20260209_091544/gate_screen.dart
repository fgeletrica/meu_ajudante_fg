import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'package:meu_ajudante_fg/routes/app_routes.dart';
import '../services/app_mode_store.dart';
import '../services/auth/auth_service.dart';
import 'about_screen.dart';
import 'mode_select_screen.dart';
import 'dart:convert';
import '../core/local_store.dart';
import 'calc_history_screen.dart';

class GateScreen extends StatelessWidget {
  const GateScreen({super.key});

  // === LAST_CALC_CARD_V1 ===

  Future<Map<String, dynamic>?> _loadLastCalc() async {
    try {
      final list = await LocalStore.getCalcHistoryRaw();
      if (list.isEmpty) return null;

      final raw = list.first;
      if (raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;

      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _lastCalcCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadLastCalc(),
      builder: (context, snap) {
        final data = snap.data;

        if (snap.connectionState != ConnectionState.done) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border.withOpacity(.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: AppTheme.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Carregando último cálculo...',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          );
        }

        if (data == null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.border.withOpacity(.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: AppTheme.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sem cálculos ainda. Faça o primeiro no “Cálculo Elétrico”.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.85),
                        fontWeight: FontWeight.w800,
                        height: 1.2),
                  ),
                ),
              ],
            ),
          );
        }

        final title = (data['title'] ?? 'Cálculo').toString();
        final pot = (data['potW'] ?? '').toString();
        final tens = (data['tensaoV'] ?? '').toString();
        final dist = (data['distM'] ?? '').toString();
        final cabo = (data['caboMm2'] ?? '').toString();
        final disj = (data['disjA'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.gold.withOpacity(.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: AppTheme.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Último cálculo',
                      style: TextStyle(
                          color: Colors.white.withOpacity(.9),
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Potência: ${pot}W • Tensão: ${tens}V • Dist: ${dist}m\nCabo: ${cabo}mm² • Disj: ${disj}A',
                style: TextStyle(
                    color: Colors.white.withOpacity(.78),
                    fontWeight: FontWeight.w700,
                    height: 1.2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.calc,
                          arguments: {
                            'title': title,
                            'powerW': pot,
                            'voltage': tens,
                          },
                        );
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('Repetir',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side:
                            BorderSide(color: AppTheme.border.withOpacity(.35)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CalcHistoryScreen()),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Histórico',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _openModeSelect(BuildContext context) async {
    await AppModeStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService.signOut();
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.authGate, (_) => false);
  }

  Widget _gridCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    bool proTag = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _go(context, route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border.withOpacity(.35)),
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
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border.withOpacity(.25)),
                  ),
                  child: Icon(icon, color: AppTheme.gold),
                ),
                const Spacer(),
                if (proTag)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(.14),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppTheme.gold.withOpacity(.35)),
                    ),
                    child: Text(
                      'PRO',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(.70),
                    fontWeight: FontWeight.w700,
                    height: 1.15)),
            const Spacer(),
            Row(
              children: [
                Text('Abrir',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.65),
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(.55)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTheme.gold.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.gold.withOpacity(.35)),
            ),
            child: Icon(Icons.person, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Painel Cliente.\nCrie pedidos no Marketplace e acompanhe.',
              style: TextStyle(
                  color: Colors.white.withOpacity(.9),
                  fontWeight: FontWeight.w800,
                  height: 1.25),
            ),
          ),
        ],
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
        title: const Text('Painel Cliente'),
        actions: [
          IconButton(
            tooltip: 'Tutoriais',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _go(context, AppRoutes.tutoriais),
          ),
          IconButton(
            tooltip: 'Sobre',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          IconButton(
            tooltip: 'Minha Conta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _go(context, AppRoutes.conta),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: [
          _heroCard(),
          const SizedBox(height: 12),
          _lastCalcCard(context),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _gridCard(
                context,
                icon: Icons.miscellaneous_services_outlined,
                title: 'Marketplace\nServiços',
                subtitle: 'Criar e ver pedidos',
                route: AppRoutes.marketplace,
              ),
              _gridCard(
                context,
                icon: Icons.calculate_outlined,
                title: 'Cálculo\nElétrico',
                subtitle: 'Cabo, disjuntor, queda',
                route: AppRoutes.calc,
              ),
              _gridCard(
                context,
                icon: Icons.inventory_2_outlined,
                title: 'Materiais',
                subtitle: 'Listas e estimativas',
                route: AppRoutes.materiais,
              ),
              _gridCard(
                context,
                icon: Icons.ac_unit,
                title: 'Equipamentos',
                subtitle: 'Itens e sugestões',
                route: AppRoutes.equipamentos,
                proTag: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
            ),
          ),
        ],
      ),
    );
  }
}
