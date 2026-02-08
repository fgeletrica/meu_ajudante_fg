import "package:flutter/material.dart";
import "gate_screen.dart";

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Não existe mais modo industrial. Mantido só pra não quebrar rotas antigas.
    return const GateScreen();
  }
}
