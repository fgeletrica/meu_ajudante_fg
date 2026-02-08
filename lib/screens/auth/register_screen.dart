import 'package:flutter/material.dart';

import '../../services/auth/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();

  bool _busy = false;
  bool _showPass = false;

  // client | pro
  String _role = 'client';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text.trim();
    final city = _city.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        !email.contains('@') ||
        pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha nome, e-mail válido e senha (mín. 6).')),
      );
      return;
    }

    // WhatsApp já no cadastro (pra usar marketplace sem ter que editar depois)
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Informe seu WhatsApp com DDD (ex: 11999998888).')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.signUp(
        email: email,
        password: pass,
        role: _role,
        name: name,
        city: city,
        phone: phone,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar conta: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Escolha seu perfil',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'client',
                      label: Text('Cliente'),
                      icon: Icon(Icons.home_outlined),
                    ),
                    ButtonSegment(
                      value: 'pro',
                      label: Text('Profissional'),
                      icon: Icon(Icons.engineering_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (v) => setState(() => _role = v.first),
                ),
                const SizedBox(height: 10),
                Text(
                  _role == 'pro'
                      ? 'Profissional aparece no marketplace e entra no ranking.'
                      : 'Cliente usa o app para solicitar serviços e acompanhar.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.alternate_email),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pass,
                          obscureText: !_showPass,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Senha (mín. 6)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _showPass = !_showPass),
                              icon: Icon(_showPass
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _city,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Cidade / Bairro (opcional)',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp (com DDD)',
                            hintText: 'Ex: 11999998888',
                            prefixIcon: Icon(Icons.chat_outlined),
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(_busy ? 'Criando...' : 'Criar conta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
