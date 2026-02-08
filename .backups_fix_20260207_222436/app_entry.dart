import package:flutter/material.dart;
import gate_screen.dart;

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    // App agora é somente RESIDENCIAL.
    return const GateScreen();
  }
}
