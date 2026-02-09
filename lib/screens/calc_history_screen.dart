import 'package:flutter/material.dart';
import '../services/calc/calc_history_store.dart';

class CalcHistoryScreen extends StatefulWidget {
  const CalcHistoryScreen({super.key});

  @override
  State<CalcHistoryScreen> createState() => _CalcHistoryScreenState();
}

class _CalcHistoryScreenState extends State<CalcHistoryScreen> {
  bool _loading = true;
  List<CalcHistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await CalcHistoryStore.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _deleteOne(CalcHistoryItem it) async {
    await CalcHistoryStore.remove(it.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text('Isso apaga todos os cálculos salvos neste aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Limpar')),
        ],
      ),
    );

    if (ok == true) {
      await CalcHistoryStore.clear();
      await _load();
    }
  }

  void _openDetails(CalcHistoryItem it) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF0E141E),
      builder: (_) {
        Widget row(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(k, style: TextStyle(color: Colors.white.withOpacity(.70), fontWeight: FontWeight.w700))),
                  Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detalhes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(.95))),
              const SizedBox(height: 10),
              row('Potência', '${it.powerW.toStringAsFixed(0)} W'),
              row('Tensão', '${it.voltageV} V'),
              row('Distância', '${it.distanceM.toStringAsFixed(1)} m'),
              const Divider(height: 22),
              row('Corrente', '${it.currentA.toStringAsFixed(2)} A'),
              row('Cabo', '${it.cableMm2.toStringAsFixed(it.cableMm2 == it.cableMm2.roundToDouble() ? 0 : 1)} mm²'),
              row('Disjuntor', '${it.breakerA} A'),
              row('Queda', '${it.dropV.toStringAsFixed(2)} V (${it.dropPerc.toStringAsFixed(2)}%)'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteOne(it);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Apagado do histórico ✅')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Apagar este'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Cálculos'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Limpar tudo',
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'Sem cálculos ainda.\nFaça o primeiro no “Cálculo Elétrico”.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(.70)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    final title = '${it.powerW.toStringAsFixed(0)}W • ${it.voltageV}V • ${it.distanceM.toStringAsFixed(0)}m';
                    final sub = 'Cabo ${it.cableMm2.toStringAsFixed(it.cableMm2 == it.cableMm2.roundToDouble() ? 0 : 1)}mm² • Disj ${it.breakerA}A • ${it.currentA.toStringAsFixed(1)}A';

                    return InkWell(
                      onTap: () => _openDetails(it),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 6),
                            Text(sub, style: TextStyle(color: Colors.white.withOpacity(.70))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
