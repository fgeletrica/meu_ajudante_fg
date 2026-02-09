import 'package:flutter/material.dart';

import 'calc_history_screen.dart';
import '../services/calc/calc_history_store.dart';

class CalcScreen extends StatefulWidget {
  const CalcScreen({super.key});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _powerCtrl = TextEditingController();
  final _distCtrl = TextEditingController();

  bool _fastMode = true;
  int _voltage = 220;

  String? _err;
  _CalcOut? _out;

  @override
  void dispose() {
    _powerCtrl.dispose();
    _distCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _calc() {
    setState(() {
      _err = null;
      _out = null;
    });

    final p = _parseNum(_powerCtrl.text);
    final d = _parseNum(_distCtrl.text);

    if (p == null || p <= 0) {
      setState(() => _err = 'Informe a Potência (W).');
      return;
    }
    if (d == null || d < 0) {
      setState(() => _err = 'Informe a Distância (m).');
      return;
    }

    // Corrente aproximada (monofásico): I = P / V
    final i = p / _voltage;

    // Sugestão de cabo por corrente (cobre PVC em eletroduto - heurística segura)
    final cable = _suggestCableMm2(i, fastMode: _fastMode);

    // Sugestão de disjuntor: próximo valor padrão acima de 1.25*I
    final breaker = _suggestBreakerA(i);

    // Queda de tensão (bem simplificada) - só pra dar noção
    // ΔV ≈ 2 * ρ * L * I / A   (cobre ρ≈0.0175 Ω·mm²/m)
    // L = distância ida (m), considera ida+volta => 2L
    final rho = 0.0175;
    final dv = (2 * rho * d * i) / cable;
    final dvPerc = (dv / _voltage) * 100.0;

    setState(() {
      _out = _CalcOut(
        powerW: p,
        voltageV: _voltage,
        distanceM: d,
        currentA: i,
        cableMm2: cable,
        breakerA: breaker,
        dropV: dv,
        dropPerc: dvPerc,
      );
    });
  }

  static double _suggestCableMm2(double i, {required bool fastMode}) {
    // Tabela “de bolso” (bem usada em obra) — valores conservadores:
    // 1.5mm² ~ 15A | 2.5 ~ 21A | 4 ~ 28A | 6 ~ 36A | 10 ~ 50A | 16 ~ 68A | 25 ~ 89A
    // fastMode: puxa um pouco pra baixo (mais “obra”), mas sem ficar perigoso.
    final adj = fastMode ? 1.0 : 0.9; // modo completo fica mais conservador
    final ia = i / adj;

    if (ia <= 15) return 1.5;
    if (ia <= 21) return 2.5;
    if (ia <= 28) return 4.0;
    if (ia <= 36) return 6.0;
    if (ia <= 50) return 10.0;
    if (ia <= 68) return 16.0;
    if (ia <= 89) return 25.0;
    if (ia <= 110) return 35.0;
    if (ia <= 140) return 50.0;
    return 70.0;
  }

  static int _suggestBreakerA(double i) {
    // regra simples: disj >= 1.25*I e sobe pro padrão
    final target = i * 1.25;
    const std = <int>[6, 10, 16, 20, 25, 32, 40, 50, 63, 70, 80, 100, 125, 160, 200];
    for (final a in std) {
      if (a >= target) return a;
    }
    return std.last;
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(.10))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(.22))),
      labelStyle: TextStyle(color: Colors.white.withOpacity(.72)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFF5C84C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cálculo Elétrico'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalcHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modo rápido', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white.withOpacity(.95))),
                    const SizedBox(height: 2),
                    Text('Só o essencial (obra)', style: TextStyle(color: Colors.white.withOpacity(.65))),
                  ],
                ),
              ),
              Switch(
                value: _fastMode,
                onChanged: (v) => setState(() => _fastMode = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Cálculo Elétrico', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(.95))),
          const SizedBox(height: 14),

          TextField(
            controller: _powerCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Potência (W)'),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Tensão (V)', style: TextStyle(color: Colors.white.withOpacity(.72))),
                ),
                DropdownButton<int>(
                  value: _voltage,
                  dropdownColor: const Color(0xFF0E141E),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 127, child: Text('127 V')),
                    DropdownMenuItem(value: 220, child: Text('220 V')),
                  ],
                  onChanged: (v) => setState(() => _voltage = v ?? 220),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _distCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Distância (m)'),
          ),
          const SizedBox(height: 14),

          if (_err != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withOpacity(.25)),
              ),
              child: Text(_err!, style: TextStyle(color: Colors.red.shade200, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _calc,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calcular', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 16),

          if (_out != null) _ResultCard(out: _out!),
        ],
      ),
    );
  }
}

class _CalcOut {
  final double powerW;
  final int voltageV;
  final double distanceM;
  final double currentA;
  final double cableMm2;
  final int breakerA;
  final double dropV;
  final double dropPerc;

  _CalcOut({
    required this.powerW,
    required this.voltageV,
    required this.distanceM,
    required this.currentA,
    required this.cableMm2,
    required this.breakerA,
    required this.dropV,
    required this.dropPerc,
  });
}

class _ResultCard extends StatelessWidget {
  final _CalcOut out;
  const _ResultCard({required this.out});

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: Colors.white.withOpacity(.72), fontWeight: FontWeight.w700))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warn = out.dropPerc >= 4.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resultado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(.95))),
          const SizedBox(height: 8),
          _row('Corrente estimada', '${out.currentA.toStringAsFixed(2)} A'),
          _row('Cabo sugerido', '${out.cableMm2.toStringAsFixed(out.cableMm2 == out.cableMm2.roundToDouble() ? 0 : 1)} mm²'),
          _row('Disjuntor sugerido', '${out.breakerA} A'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (warn ? Colors.orange : Colors.green).withOpacity(.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (warn ? Colors.orange : Colors.green).withOpacity(.25)),
            ),
            child: Row(
              children: [
                Icon(warn ? Icons.warning_amber_rounded : Icons.check_circle, size: 18, color: warn ? Colors.orange : Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Queda estimada: ${out.dropV.toStringAsFixed(2)} V (${out.dropPerc.toStringAsFixed(2)}%)',
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white.withOpacity(.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Obs: queda é uma estimativa simples (ida+volta). Se distância for grande, pode precisar subir o cabo.',
            style: TextStyle(color: Colors.white.withOpacity(.55)),
          ),
        ],
      ),
    );
  }
}
