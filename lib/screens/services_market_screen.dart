import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/auth/auth_service.dart';
import '../screens/community_screen.dart';

class ServicesMarketScreen extends StatefulWidget {
  const ServicesMarketScreen({super.key});

  @override
  State<ServicesMarketScreen> createState() => _ServicesMarketScreenState();
}

class _ServicesMarketScreenState extends State<ServicesMarketScreen> {
  final _sb = Supabase.instance.client;

  String _role = 'client';
  bool _loadingRole = true;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _authSub = _sb.auth.onAuthStateChange.listen((_) => _loadRole());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRole() async {
    try {
      final r = await AuthService.getMyRole();
      if (!mounted) return;
      setState(() {
        _role = (r == 'pro') ? 'pro' : 'client';
        _loadingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _role = 'client';
        _loadingRole = false;
      });
    }
  }

  bool get _isPro => _role == 'pro';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Servicos / Comunidade
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.bg,
          title: const Text('Marketplace de ...'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _RolePill(isPro: _isPro),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Serviços'),
              Tab(text: 'Comunidade'),
            ],
          ),
        ),
        body: _loadingRole
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _isPro ? _ProServices(sb: _sb) : _ClientServices(sb: _sb),
                  const CommunityScreen(),
                ],
              ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final bool isPro;
  const _RolePill({required this.isPro});

  @override
  Widget build(BuildContext context) {
    final txt = isPro ? 'PRO' : 'CLIENTE';
    final icon = isPro ? Icons.engineering : Icons.person;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFB38A2E)),
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFB38A2E)),
          const SizedBox(width: 6),
          Text(
            txt,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFFB38A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= CLIENTE (Fazer pedido) =================

class _ClientServices extends StatefulWidget {
  final SupabaseClient sb;
  const _ClientServices({required this.sb});

  @override
  State<_ClientServices> createState() => _ClientServicesState();
}

class _ClientServicesState extends State<_ClientServices> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _myItems = [];

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    final u = widget.sb.auth.currentUser;
    if (u == null) {
      setState(() {
        _loading = false;
        _err = 'Usuário não logado';
      });
      return;
    }

    try {
      final res = await widget.sb
          .from('service_requests')
          .select()
          .eq('user_id', u.id)
          .order('created_at', ascending: false);

      setState(() {
        _myItems = List<Map<String, dynamic>>.from(res as List);
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newPedido() async {
    final u = widget.sb.auth.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não logado')),
      );
      return;
    }

    final titleCtl = TextEditingController();
    final cityCtl = TextEditingController();
    final descCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo pedido'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: cityCtl, decoration: const InputDecoration(labelText: 'Cidade')),
              TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Descrição'), maxLines: 4),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Criar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final prof = await widget.sb
          .from('profiles')
          .select('name,phone,city,avatar_url')
          .eq('id', u.id)
          .maybeSingle();

      final name = (prof?['name'] ?? '').toString();
      final phone = (prof?['phone'] ?? '').toString();
      final avatar = (prof?['avatar_url'] ?? '').toString();

      final city = cityCtl.text.trim().isNotEmpty
          ? cityCtl.text.trim()
          : (prof?['city'] ?? '').toString();

      await widget.sb.from('service_requests').insert({
        'user_id': u.id,
        'title': titleCtl.text.trim(),
        'description': descCtl.text.trim(),
        'city': city,
        'contact_name': name,
        'contact_phone': phone,
        'contact_photo_url': avatar,
        'done': false,
      });

      if (!mounted) return;
      await _loadMine();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido criado!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_err != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadMine, child: const Text('Recarregar')),
          ],
        ),
      );
    }

    // Layout igual print: botao grande + vazio com texto
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Fazer pedido'),
                    Tab(text: 'Comunidade'),
                  ],
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height - 180,
                  child: TabBarView(
                    children: [
                      // Fazer pedido
                      Column(
                        children: [
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _newPedido,
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Novo pedido',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDBA73A),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Expanded(
                            child: _myItems.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Você ainda não criou pedidos.\nToque em "Novo pedido".',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 18, color: Colors.white70),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _myItems.length,
                                    itemBuilder: (_, i) {
                                      final it = _myItems[i];
                                      return Card(
                                        child: ListTile(
                                          title: Text((it['title'] ?? '').toString()),
                                          subtitle: Text('Cidade: ${(it['city'] ?? '').toString()}'),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),

                      // Comunidade (atalho dentro, igual print antigo)
                      const CommunityScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= PROFISSIONAL (aceitar + WhatsApp) =================

class _ProServices extends StatefulWidget {
  final SupabaseClient sb;
  const _ProServices({required this.sb});

  @override
  State<_ProServices> createState() => _ProServicesState();
}

class _ProServicesState extends State<_ProServices> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final res = await widget.sb
          .from('service_requests')
          .select()
          .eq('done', false)
          .order('created_at', ascending: false);

      setState(() {
        _items = List<Map<String, dynamic>>.from(res as List);
      });
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(Map<String, dynamic> it) async {
    final u = widget.sb.auth.currentUser;
    if (u == null) return;

    if (it['accepted_by'] != null) return;

    try {
      final prof = await widget.sb.from('profiles').select('name,avatar_url').eq('id', u.id).maybeSingle();
      final name = (prof?['name'] ?? '').toString();
      final avatar = (prof?['avatar_url'] ?? '').toString();

      await widget.sb
          .from('service_requests')
          .update({
            'accepted_by': u.id,
            'accepted_at': DateTime.now().toIso8601String(),
            'accepted_name': name,
            'accepted_avatar_url': avatar,
          })
          .eq('id', it['id']);

      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aceito!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _openWhatsApp(String phone, String title) async {
    final p = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente sem WhatsApp cadastrado')),
      );
      return;
    }

    final msg = Uri.encodeComponent('Oi! Vi seu pedido no FG Elétrica: "$title". Posso te ajudar?');
    final withDDI = p.startsWith('55') ? p : '55$p';
    final uri = Uri.parse('https://wa.me/$withDDI?text=$msg');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui abrir o WhatsApp')),
      );
    }
  }

  Widget _chip(String txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(txt, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_err != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_err!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Recarregar')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Serviços'),
                Tab(text: 'Comunidade'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Nenhum pedido aberto agora.', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _load, child: const Text('Recarregar')),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final it = _items[i];
                            final title = (it['title'] ?? '').toString();
                            final city = (it['city'] ?? '').toString();
                            final clientName = (it['contact_name'] ?? '').toString();
                            final phone = (it['contact_phone'] ?? '').toString();

                            final u = widget.sb.auth.currentUser;
                            final acceptedBy = it['accepted_by'];
                            final acceptedByMe = (u != null && acceptedBy == u.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(child: Icon(Icons.person)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    (it['description'] ?? '').toString(),
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _chip('Cidade: $city'),
                                      const SizedBox(width: 10),
                                      _chip('Cliente: $clientName'),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (acceptedByMe)
                                    _chip('✅ Aceito por você')
                                  else if (acceptedBy != null)
                                    _chip('✅ Já aceito')
                                  else
                                    const SizedBox.shrink(),
                                  const SizedBox(height: 14),

                                  // Botao grande igual print
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton.icon(
                                      onPressed: acceptedByMe
                                          ? () => _openWhatsApp(phone, title)
                                          : (acceptedBy == null ? () => _accept(it) : null),
                                      icon: Icon(acceptedByMe ? Icons.chat : Icons.check),
                                      label: Text(
                                        acceptedByMe ? 'Chamar no WhatsApp' : 'Aceitar',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFDBA73A),
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  const CommunityScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
