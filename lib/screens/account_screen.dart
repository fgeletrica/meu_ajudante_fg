import 'package:flutter/material.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';
import 'package:meu_ajudante_fg/routes/app_routes.dart';
import '../services/auth/auth_service.dart';
import '../services/avatar_cache.dart';
import '../services/local_store.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String _role = 'client';

  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _profCtrl = TextEditingController();
  String? _err;

  String _avatarUrl = '';
  bool _uploadingAvatar = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _profCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final u = AuthService.user;
      if (u == null) throw Exception('Usuário não logado');

      final prof = await _sb
          .from('profiles')
          .select('name, city, phone, role, avatar_url, bio, profession')
          .eq('id', u.id)
          .maybeSingle();

      final rawRole = (prof?['role'] ?? '').toString().trim();
      _role = (rawRole == 'pro') ? 'pro' : 'client';
      // sincroniza cache local (evita herdar role de outra conta)_nameCtrl.text = (prof?['name'] ?? '').toString();
      _cityCtrl.text = (prof?['city'] ?? '').toString();
      _phoneCtrl.text = (prof?['phone'] ?? '').toString();

      _bioCtrl.text = (prof?['bio'] ?? '').toString();
      _profCtrl.text = (prof?['profession'] ?? '').toString();

      _avatarUrl = (prof?['avatar_url'] ?? '').toString();

      // cache local (evita reload)
      await AvatarCache.init();
      if (u != null && _avatarUrl.trim().isNotEmpty) {
        await AvatarCache.rememberUserId(u.id, _avatarUrl);
        final ph = _phoneCtrl.text.trim();
        if (ph.isNotEmpty) await AvatarCache.rememberPhone(ph, _avatarUrl);
      }
      if (mounted) {
        await AvatarCache.warm(context, _avatarUrl);
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final u = AuthService.user;
    if (u == null) return;

    try {
      setState(() => _uploadingAvatar = true);

      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 900,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploadingAvatar = false);
        return;
      }

      final bytes = await picked.readAsBytes();
      final ext =
          picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final path =
          '${u.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // upload no bucket avatars (PUBLIC)
      await _sb.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType:
                  ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );

      final url = _sb.storage.from('avatars').getPublicUrl(path);

      // salva no profile
      await _sb.from('profiles').upsert({
        'id': u.id,
        'avatar_url': url,
      });

      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });

      // cache local (evita reload)
      await AvatarCache.init();
      await AvatarCache.rememberUserId(u.id, url);
      final ph = _phoneCtrl.text.trim();
      if (ph.isNotEmpty) await AvatarCache.rememberPhone(ph, url);
      if (mounted) await AvatarCache.warm(context, url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto atualizada ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar foto: $e')),
      );
    }
  }

  Future<void> _save() async {
    final u = AuthService.user;
    if (u == null) return;

    final name = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() => _err = null);

    try {
      await _sb.from('profiles').upsert({
        'id': u.id,
        'name': name,
        'city': city,
        'phone': phone,
        'bio': _bioCtrl.text.trim(),
        'profession': _profCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta salva ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.authGate, (_) => false);
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.gold.withOpacity(.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.gold,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  // === FG_AVATAR_UI_V1 ===
  Widget _avatarPickerCard() {
    final has = _avatarUrl.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white.withOpacity(.08),
                backgroundImage: has ? NetworkImage(_avatarUrl) : null,
                child: !has
                    ? const Icon(Icons.person, size: 34, color: Colors.white)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.black.withOpacity(.15)),
                    ),
                    child: _uploadingAvatar
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt,
                            size: 16, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Foto de perfil',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toque na câmera para escolher uma foto.\nEla aparece no Marketplace.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.75),
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: (borderColor ?? AppTheme.border).withOpacity(.35)),
      ),
      child: child,
    );
  }

  Widget _field(String label, TextEditingController c,
      {TextInputType? kb, String? hint}) {
    return TextField(
      controller: c,
      keyboardType: kb,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.35)),
        labelStyle: TextStyle(color: Colors.white.withOpacity(.7)),
        filled: true,
        fillColor: AppTheme.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border.withOpacity(.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.gold.withOpacity(.8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _role == 'pro' ? 'Minha Conta (Profissional)' : 'Minha Conta (Cliente)';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text(title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              children: [
                // FG_AVATAR_UI_V1_IN_BUILD
                _avatarPickerCard(),
                const SizedBox(height: 12),
                _sectionCard(
                  borderColor: AppTheme.gold,
                  child: Row(
                    children: [
                      Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(.12),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppTheme.gold.withOpacity(.35)),
                        ),
                        child: Icon(Icons.account_circle, color: AppTheme.gold),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seu perfil',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.92),
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seu WhatsApp aparece no Marketplace quando você cria pedidos.',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(.7),
                                  fontWeight: FontWeight.w700,
                                  height: 1.15),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _badge(_role == 'pro' ? 'PRO' : 'CLIENTE'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    children: [
                      _field('Nome', _nameCtrl, hint: 'Ex: Felype'),
                      const SizedBox(height: 10),
                      _field('Cidade/Bairro', _cityCtrl,
                          hint: 'Ex: RJ - Campo Grande'),
                      const SizedBox(height: 10),
                      _field('WhatsApp (com DDD)', _phoneCtrl,
                          kb: TextInputType.phone, hint: 'Ex: 21999999999'),
                      const SizedBox(height: 10),
                      _field('Profissão', _profCtrl,
                          hint: 'Ex: Eletricista residencial'),
                      const SizedBox(height: 10),
                      _field('Bio', _bioCtrl,
                          hint: 'Ex: Atendo RJ • Instalações e manutenção'),
                    ],
                  ),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Text(_err!,
                      style: TextStyle(
                          color: Colors.red.withOpacity(.9),
                          fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                              color: AppTheme.border.withOpacity(.35)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recarregar',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.red.withOpacity(.55)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sair',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
