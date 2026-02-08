import 'dart:async';
import '../services/auth/role_resolver.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/role_resolver.dart';
import '../services/avatar_cache.dart';
import 'community_screen.dart';

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
    () async {
      try {
        final role = await RoleResolver.resolveRole();
        if (mounted) setState(() => _role = role);
      } catch (_) {}
    }();
    _loadRole();
    _authSub = _sb.auth.onAuthStateChange.listen((_) => _loadRole());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRole() async {
    if (!mounted) return;
    setState(() => _loadingRole = true);
    try {
      final r = await RoleResolver.resolveRole();
      if (!mounted) return;
      setState(() {
        _role = r == 'pro' ? 'pro' : 'client';
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
    if (_loadingRole) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: const Text('Marketplace de Serviços'),
          backgroundColor: AppTheme.bg,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = <Tab>[
      Tab(text: _isPro ? 'Serviços' : 'Fazer pedido'),
      const Tab(text: 'Comunidade'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          title: const Text('Marketplace de Serviços'),
          backgroundColor: AppTheme.bg,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.gold.withOpacity(.35)),
              ),
              child: Row(
                children: [
                  Icon(_isPro ? Icons.engineering : Icons.person,
                      size: 16, color: AppTheme.gold),
                  const SizedBox(width: 6),
                  Text(
                    _isPro ? 'PRO' : 'CLIENTE',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          bottom: TabBar(
            tabs: tabs,
            indicatorColor: AppTheme.gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(.65),
            labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: TabBarView(
          children: [
            _isPro ? _ProTab(sb: _sb) : _ClientTab(sb: _sb),
            const CommunityScreen(),
          ],
        ),
      ),
    );
  }
}

class _ClientTab extends StatefulWidget {
  final SupabaseClient sb;
  const _ClientTab({required this.sb});

  @override
  State<_ClientTab> createState() => _ClientTabState();
}

class _ClientTabState extends State<_ClientTab> {
  bool _loading = true;
  String? _err;
  List<Map<String, dynamic>> _items = [];

  Future<Map<String, dynamic>> _myProfile() async {
    final u = AuthService.user;
    if (u == null) throw Exception('Usuário não logado');
    final prof = await widget.sb
        .from('profiles')
        .select('name, city, phone, avatar_url')
        .eq('id', u.id)
        .maybeSingle();
    return (prof ?? {});
  }

  @override
  void initState() {
    super.initState();
    AvatarCache.init();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final u = AuthService.user;
      if (u == null) throw Exception('Usuário não logado');

      final res = await widget.sb
          .from('service_requests')
          .select(
              'id, created_at, title, city, done, client_rating, client_review, accepted_by, accepted_at')
          .eq('user_id', u.id)
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

  // === CLIENT_REVIEW_V1 ===
  Future<void> _askReviewAndComplete(String id, String title) async {
    int rating = 5;
    final ctrl = TextEditingController();

    Future<void> submit() async {
      try {
        await widget.sb.from('service_requests').update({
          'done': true,
          'client_rating': rating,
          'client_review': ctrl.text.trim(),
          'reviewed_at': DateTime.now().toIso8601String(),
        }).eq('id', id);

        if (!mounted) return;
        Navigator.pop(context);
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Concluído e avaliado ✅')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar avaliação: $e')),
        );
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Widget star(int i) {
            final on = i <= rating;
            return IconButton(
              onPressed: () => setLocal(() => rating = i),
              icon: Icon(on ? Icons.star : Icons.star_border),
              color: on ? AppTheme.gold : Colors.white.withOpacity(.55),
              tooltip: '$i',
            );
          }

          return AlertDialog(
            backgroundColor: AppTheme.card,
            title: const Text(
              'Avaliar serviço',
              style:
                  TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Pedido concluído' : title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nota:',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.8),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(children: [star(1), star(2), star(3), star(4), star(5)]),
                  const SizedBox(height: 8),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Comentário (opcional)',
                      labelStyle:
                          TextStyle(color: Colors.white.withOpacity(.7)),
                      filled: true,
                      fillColor: AppTheme.bg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppTheme.border.withOpacity(.35)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: AppTheme.gold.withOpacity(.8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dica: essa avaliação ajuda a melhorar o Marketplace.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.65),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await widget.sb
                        .from('service_requests')
                        .update({'done': true}).eq('id', id);
                    if (!mounted) return;
                    Navigator.pop(context);
                    await _load();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Concluído ✅')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                },
                child: const Text('Pular'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('Salvar',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createRequest() async {
    final title = TextEditingController();
    final desc = TextEditingController();

    Future<void> go() async {
      try {
        final u = AuthService.user;
        if (u == null) throw Exception('Usuário não logado');

        final prof = await _myProfile();
        final name = (prof['name'] ?? '').toString().trim();
        final city = (prof['city'] ?? '').toString().trim();
        final phone = (prof['phone'] ?? '').toString().trim();
        final avatar = (prof['avatar_url'] ?? '').toString().trim();

        if (phone.isEmpty || avatar.isEmpty) {
          throw Exception(
              'Complete seu WhatsApp e Foto em Minha Conta antes de publicar.');
        }

        await widget.sb.from('service_requests').insert({
          'user_id': u.id,
          'title': title.text.trim(),
          'description': desc.text.trim(),
          'city': city,
          'contact_name': name,
          'contact_phone': phone,
          'contact_photo_url': avatar,
          'done': false,
        });

        if (!mounted) return;
        Navigator.pop(context);
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Novo Pedido',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              // === PREVIEW DO CLIENTE ===
              FutureBuilder(
                future: _myProfile(),
                builder: (context, snap) {
                  final p = snap.data as Map<String, dynamic>?;
                  final avatar = (p?['avatar_url'] ?? '').toString().trim();
                  final phone = (p?['phone'] ?? '').toString().trim();
                  final ok = avatar.isNotEmpty && phone.isNotEmpty;

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white.withOpacity(.08),
                        backgroundImage:
                            avatar.isEmpty ? null : NetworkImage(avatar),
                        child: avatar.isEmpty
                            ? const Icon(Icons.person,
                                size: 36, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ok
                            ? 'Seu pedido aparecerá assim para os profissionais'
                            : 'Complete Foto + WhatsApp em Minha Conta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ok
                              ? Colors.white.withOpacity(.8)
                              : Colors.redAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),

              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título')),
              const SizedBox(height: 8),
              TextField(
                  controller: desc,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 10),
              Text(
                'Obs: Cidade e WhatsApp vêm da sua Conta automaticamente.',
                style: TextStyle(
                    color: Colors.white.withOpacity(.75),
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final prof = await _myProfile();
              final avatar = (prof['avatar_url'] ?? '').toString().trim();
              final phone = (prof['phone'] ?? '').toString().trim();

              if (avatar.isEmpty || phone.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Preencha Foto e WhatsApp em Minha Conta')),
                );
                return;
              }
              await go();
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _markDone(String id, String title, {String? acceptedBy}) async {
    final ab = (acceptedBy ?? '').toString().trim();
    if (ab.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Aguarde um profissional aceitar seu pedido antes de concluir.')),
      );
      return;
    }
    await _askReviewAndComplete(id, title);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _createRequest,
              icon: const Icon(Icons.add),
              label: const Text('Novo pedido',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _err != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_err!,
                              style: const TextStyle(color: Colors.red))))
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                              'Você ainda não criou pedidos.\nToque em “Novo pedido”.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.8),
                                  fontWeight: FontWeight.w800)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final it = _items[i];
                            final id = (it['id'] ?? '').toString();
                            final done = (it['done'] == true);

                            return Card(
                              color: AppTheme.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text((it['title'] ?? '').toString(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white)),
                                    const SizedBox(height: 6),
                                    Text(
                                        'Cidade: ${(it['city'] ?? '').toString()}',
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(.75),
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 10),
                                    // === PRO_AVATAR_FROM_REQUEST_V1 ===
                                    Row(
                                      children: [
                                        _pill(done ? 'Concluído' : 'Aberto'),
                                        const Spacer(),
                                        if (!done)
                                          TextButton.icon(
                                            onPressed: () => _markDone(
                                              id,
                                              (it['title'] ?? '').toString(),
                                              acceptedBy:
                                                  (it['accepted_by'] ?? '')
                                                      .toString(),
                                            ),
                                            icon: const Icon(Icons.check),
                                            label:
                                                const Text('Marcar concluído'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border.withOpacity(.25)),
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white.withOpacity(.85),
              fontWeight: FontWeight.w900,
              fontSize: 12)),
    );
  }
}

class _ProTab extends StatefulWidget {
  final SupabaseClient sb;
  const _ProTab({required this.sb});

  @override
  State<_ProTab> createState() => _ProTabState();
}

class _ProTabState extends State<_ProTab> {
  bool _loading = true;
  final Map<String, _ClientStats> _statsByUserId = {};

  String? _err;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    AvatarCache.init();
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
          .select(
              'user_id, id, created_at, title, description, city, contact_name, contact_phone, contact_photo_url, done, client_rating, accepted_by, accepted_at')
          .or('done.is.null,done.eq.false')
          .order('created_at', ascending: false);

      setState(() => _items = List<Map<String, dynamic>>.from(res as List));

      await _loadClientStats();
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClientStats() async {
    try {
      final ids = <String>{};
      for (final it in _items) {
        final uid = (it['user_id'] ?? '').toString().trim();
        if (uid.isNotEmpty) ids.add(uid);
      }
      if (ids.isEmpty) return;

      final res = await widget.sb
          .from('service_requests')
          .select('user_id, client_rating')
          .inFilter('user_id', ids.toList())
          .not('client_rating', 'is', null);

      final rows = List<Map<String, dynamic>>.from(res as List);
      final tmp = <String, List<int>>{};
      for (final r in rows) {
        final uid = (r['user_id'] ?? '').toString().trim();
        final v = r['client_rating'];
        if (uid.isEmpty || v == null) continue;
        final n = (v is num) ? v.toInt() : int.tryParse(v.toString()) ?? 0;
        if (n <= 0) continue;
        tmp.putIfAbsent(uid, () => []).add(n);
      }

      _statsByUserId.clear();
      tmp.forEach((uid, list) {
        if (list.isEmpty) return;
        var sum = 0;
        for (final x in list) {
          sum += x;
        }
        final avg = sum / list.length;
        _statsByUserId[uid] = _ClientStats(count: list.length, avg: avg);
      });
    } catch (_) {
      // não quebra o app por causa de stats
    }
  }

  Future<void> _openWhatsApp(String phone, String title) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final msg = Uri.encodeComponent(
        'Olá! Vi seu pedido no Marketplace: "$title". Posso te ajudar?');
    final uri = Uri.parse('https://wa.me/55$digits?text=$msg');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _acceptRequest(String requestId) async {
    final u = AuthService.user;
    if (u == null) return;

    try {
      // tenta aceitar somente se ainda estiver livre
      final res = await widget.sb
          .from('service_requests')
          .update({
            'accepted_by': u.id,
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .isFilter('accepted_by', null)
          .select('id');

      // se não atualizou nada, alguém aceitou antes
      if (res is List && res.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Esse pedido já foi aceito por outro profissional.')),
        );
        await _load();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pedido aceito ✅ Agora você pode atender.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao aceitar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null)
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_err!, style: const TextStyle(color: Colors.red))));

    if (_items.isEmpty) {
      return Center(
          child: Text('Sem pedidos abertos agora.',
              style: TextStyle(
                  color: Colors.white.withOpacity(.8),
                  fontWeight: FontWeight.w800)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final it = _items[i];
          final title = (it['title'] ?? '').toString();
          final desc = (it['description'] ?? '').toString();
          final city = (it['city'] ?? '').toString();
          final name = (it['contact_name'] ?? '').toString();

          final phone = (it['contact_phone'] ?? '').toString();

          final requestId = (it['id'] ?? '').toString();
          final acceptedBy = (it['accepted_by'] ?? '').toString().trim();
          final myId = (AuthService.user?.id ?? '').toString().trim();
          final isMine =
              acceptedBy.isNotEmpty && myId.isNotEmpty && acceptedBy == myId;
          final isTaken = acceptedBy.isNotEmpty && !isMine;
          final canChat = phone.trim().isNotEmpty &&
              !isTaken; // evita "roubar" pedido aceito por outro

          // avatar do cliente vem do próprio pedido (salvo na criação)
          String avatarUrl =
              ((it['contact_photo_url'] ?? '').toString()).trim();
          if (avatarUrl.isEmpty) {
            // fallback: cache local por telefone
            avatarUrl = AvatarCache.getLocalByPhone(phone);
          }
          if (avatarUrl.isNotEmpty) {
            // salva local e aquece cache
            AvatarCache.rememberPhone(phone, avatarUrl);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              AvatarCache.warm(context, avatarUrl);
            });
          }

          // === PRO_AVATAR_IN_CARD_V3 (scope correto)
          // === PRO_AVATAR_IN_CARD_V3 (scope correto) ===
          // === PRO_AVATAR_IN_CARD_V1 ===
          return Card(
            color: AppTheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === PRO_AVATAR_IN_CARD_V1 ===
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withOpacity(.08),
                        backgroundImage: avatarUrl.trim().isEmpty
                            ? null
                            : NetworkImage(avatarUrl),
                        child: avatarUrl.trim().isEmpty
                            ? const Icon(Icons.person,
                                size: 18, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  if (desc.trim().isNotEmpty)
                    Text(desc,
                        style: TextStyle(color: Colors.white.withOpacity(.75))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Cidade: $city'),
                      _pill('Cliente: $name'),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (isMine) _pill('✅ Aceito por você'),
                      if (!isMine && !isTaken) _pill('🟢 Pedido livre'),
                      if (isTaken) _pill('🔒 Já aceito'),
                      const Spacer(),
                      if (!isMine && !isTaken)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _acceptRequest(requestId),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Aceitar',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
                    final uid = (it['user_id'] ?? '').toString().trim();
                    final st = uid.isEmpty ? null : _statsByUserId[uid];
                    if (st == null || st.count <= 0)
                      return const SizedBox.shrink();
                    return Align(
                      alignment: Alignment.centerLeft,
                      child:
                          _pill('⭐ ${st.avg.toStringAsFixed(1)} (${st.count})'),
                    );
                  }),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed:
                          canChat ? () => _openWhatsApp(phone, title) : null,
                      icon: const Icon(Icons.chat),
                      label: Text(
                          phone.trim().isEmpty
                              ? 'Cliente sem WhatsApp'
                              : (isTaken
                                  ? 'Pedido já aceito'
                                  : 'Chamar no WhatsApp'),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border.withOpacity(.25)),
      ),
      child: Text(text,
          style: TextStyle(
              color: Colors.white.withOpacity(.85),
              fontWeight: FontWeight.w800,
              fontSize: 12)),
    );
  }
}

class _ClientStats {
  final int count;
  final double avg;
  const _ClientStats({required this.count, required this.avg});
}
