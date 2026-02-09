import 'dart:math';

class CalcInput {
  final double powerW;
  final double voltageV; // 127 ou 220
  final double distanceM; // ida (m)
  final bool quickMode;

  const CalcInput({
    required this.powerW,
    required this.voltageV,
    required this.distanceM,
    required this.quickMode,
  });
}

class CalcResult {
  final double currentA;

  final double cableMm2;
  final int breakerA;

  final double vdropV;
  final double vdropPct;

  final double earthMm2;

  const CalcResult({
    required this.currentA,
    required this.cableMm2,
    required this.breakerA,
    required this.vdropV,
    required this.vdropPct,
    required this.earthMm2,
  });

  Map<String, dynamic> toMap() => {
        'currentA': currentA,
        'cableMm2': cableMm2,
        'breakerA': breakerA,
        'vdropV': vdropV,
        'vdropPct': vdropPct,
        'earthMm2': earthMm2,
      };
}

/// Motor do cálculo (puro, sem UI).
/// Objetivo: manter resultado consistente e previsível.
/// OBS: se você tinha uma tabela específica antes, a gente ajusta os arrays abaixo.
class CalcEngine {
  // Resistividade do cobre (Ω·mm²/m) ~20°C
  static const double _rhoCu = 0.0175;

  // Ampacidade simplificada (A) por seção (mm²)
  // (tabela padrão "segura" pra uso geral; se sua versão antiga tinha outros números, trocamos aqui)
  static const List<double> _sections = [1.5, 2.5, 4, 6, 10, 16, 25, 35, 50, 70];
  static const List<double> _ampacity = [15, 21, 28, 36, 50, 68, 89, 110, 140, 175];

  // Disjuntores padronizados (A)
  static const List<int> _breakers = [6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200];

  static CalcResult compute(CalcInput input) {
    final p = input.powerW;
    final v = input.voltageV;
    final l = input.distanceM;

    if (p <= 0) throw Exception('Potência inválida');
    if (v <= 0) throw Exception('Tensão inválida');
    if (l < 0) throw Exception('Distância inválida');

    // Corrente
    final i = p / v;

    // 1) Seção mínima por corrente (ampacidade)
    final baseSection = _pickSectionByCurrent(i);

    // 2) Queda de tensão (monofásico: ida e volta = 2L)
    // R = 2 * ρ * L / S
    final r = (2.0 * _rhoCu * l) / baseSection;
    final vdrop = i * r;
    final vdropPct = (vdrop / v) * 100.0;

    // 3) Se a queda ficar alta, sobe seção até ficar aceitável
    // Meta comum: <= 4% (ajustável)
    final targetPct = input.quickMode ? 6.0 : 4.0;

    var finalSection = baseSection;
    var finalVdrop = vdrop;
    var finalVdropPct = vdropPct;

    while (finalVdropPct > targetPct) {
      final next = _nextSection(finalSection);
      if (next == finalSection) break; // já chegou no máximo
      finalSection = next;
      final r2 = (2.0 * _rhoCu * l) / finalSection;
      finalVdrop = i * r2;
      finalVdropPct = (finalVdrop / v) * 100.0;
    }

    // 4) Disjuntor: próximo padrão acima da corrente
    final breaker = _pickBreaker(i);

    // 5) Terra (regra simples típica):
    // - até 16mm²: terra = fase
    // - 25..35: terra 16
    // - 50..70: terra 25
    // - acima: terra 35
    final earth = _pickEarth(finalSection);

    return CalcResult(
      currentA: _round(i, 2),
      cableMm2: finalSection,
      breakerA: breaker,
      vdropV: _round(finalVdrop, 2),
      vdropPct: _round(finalVdropPct, 2),
      earthMm2: earth,
    );
  }

  static double _pickSectionByCurrent(double i) {
    for (var idx = 0; idx < _sections.length; idx++) {
      if (i <= _ampacity[idx]) return _sections[idx];
    }
    return _sections.last;
  }

  static double _nextSection(double s) {
    for (var idx = 0; idx < _sections.length; idx++) {
      if (_sections[idx] == s && idx + 1 < _sections.length) return _sections[idx + 1];
    }
    return s;
  }

  static int _pickBreaker(double i) {
    for (final b in _breakers) {
      if (i <= b) return b;
    }
    return _breakers.last;
  }

  static double _pickEarth(double phaseMm2) {
    if (phaseMm2 <= 16) return phaseMm2;
    if (phaseMm2 <= 35) return 16;
    if (phaseMm2 <= 70) return 25;
    return 35;
  }

  static double _round(double v, int n) {
    final p = pow(10, n).toDouble();
    return (v * p).roundToDouble() / p;
  }
}
