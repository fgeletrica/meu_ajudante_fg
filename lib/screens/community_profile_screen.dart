import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../services/auth/auth_service.dart';

class CommunityProfileScreen extends StatefulWidget {
  final String userId;
  final String? fallbackName;
  final String? fallbackAvatar;

  const CommunityProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
    this.fallbackAvatar,
  });

  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen> {
  final _sb = Supabase.instance.client;

  bool _loading = true;
  String? _err;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];

  int _followers = 0;
  int _following = 0;
  bool _isFollowing = false;

  String get _uid => widget.userId.trim();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      await Future.wait([
        _loadProfile(),
        _loadPosts(),
        _loadCountsAndFollowState(),
      ]);
    } catch (e) {
      _err = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    // tenta pegar do public_profiles (se existir), senão só usa fallback
    try {
      final row = await _sb
          .from('public_profiles')
          .select('id, role, name, city, avatar_url, bio, profession')
          .eq('id', _uid)
          .maybeSingle();

      if (mounted) setState(() => _profile = row);
    } catch (_) {
      // ignora, vai de fallback
    }
  }

  Future<void> _loadPosts() async {
    // posts do usuário (feed do perfil)
    final res = await _sb
        .from('posts')
        .select('id, created_at, author_id, media_url, media_type, caption, like_count, comment_count')
        .eq('author_id', _uid)
        .order('created_at', ascending: false)
        .limit(60);

    if (!mounted) return;
    setState(() => _posts = List<Map<String, dynamic>>.from(res as List));
  }

  Future<void> _loadCountsAndFollowState() async {
    final me = AuthService.user;
    // followers/following via RPC (mais leve). Se não existir, faz fallback.
    int followers = 0;
    int following = 0;

    try {
      final a = await _sb.rpc('count_followers', {'p_user': _uid});
      final b = await _sb.rpc('count_following', {'p_user': _uid});
      followers = (a is int) ? a : int.tryParse('$a') ?? 0;
      following = (b is int) ? b : int.tryParse('$b') ?? 0;
    } catch (_) {
      // fallback: conta na mão (pode ser mais pesado, mas funciona)
      try {
        final fa = await _sb.from('user_follows').select('follower_id').eq('following_id', _uid);
        final fb = await _sb.from('user_follows').select('following_id').eq('follower_id', _uid);
        followers = (fa is List) ? fa.length : 0;
        following = (fb is List) ? fb.length : 0;
      } catch (_) {}
    }

    bool isFollowing = false;
    if (me != null && me.id != _uid) {
      try {
        final rel = await _sb
            .from('user_follows')
            .select('follower_id')
            .eq('follower_id', me.id)
            .eq('following_id', _uid)
            .maybeSingle();
        isFollowing = rel != null;
      } catch (_) {
        isFollowing = false;
      }
    }

    if (!mounted) return;
    setState(() {
      _followers = followers;
      _following = following;
      _isFollowing = isFollowing;
    });
  }

  Future<void> _toggleFollow() async {
    final me = AuthService.user;
    if (me == null) return;
    if (me.id == _uid) return;

    try {
      if (_isFollowing) {
        await _sb
            .from('user_follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', _uid);
      } else {
        await _sb.from('user_follows').insert({
          'follower_id': me.id,
          'following_id': _uid,
        });
      }
      await _loadCountsAndFollowState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao seguir: $e')),
      );
    }
  }

  void _openImage(String url) {
    final u = url.trim();
    if (u.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.9),
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(u, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? {};
    final name = (p['name'] ?? widget.fallbackName ?? '').toString().trim();
    final avatar = (p['avatar_url'] ?? widget.fallbackAvatar ?? '').toString().trim();
    final bio = (p['bio'] ?? '').toString().trim();

    final me = AuthService.user;
    final isMe = (me != null && me.id == _uid);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text(name.isEmpty ? 'Perfil' : name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // HEADER (tipo Instagram)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: Colors.white.withOpacity(.08),
                            backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                            child: avatar.isEmpty
                                ? const Icon(Icons.person, color: Colors.white70, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'Usuário' : name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(bio, style: TextStyle(color: Colors.white.withOpacity(.85))),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _StatBox(label: 'Posts', value: _posts.length),
                                    const SizedBox(width: 10),
                                    _StatBox(label: 'Seguidores', value: _followers),
                                    const SizedBox(width: 10),
                                    _StatBox(label: 'Seguindo', value: _following),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (!isMe)
                                  SizedBox(
                                    height: 38,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing
                                            ? Colors.white.withOpacity(.12)
                                            : AppTheme.gold,
                                        foregroundColor: _isFollowing ? Colors.white : Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _toggleFollow,
                                      child: Text(_isFollowing ? 'Seguindo' : 'Seguir'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      Divider(color: Colors.white.withOpacity(.12)),
                      const SizedBox(height: 8),

                      // GRID (3 colunas)
                      if (_posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'Sem posts ainda.',
                              style: TextStyle(color: Colors.white.withOpacity(.7)),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) {
                            final it = _posts[i];
                            final url = (it['media_url'] ?? '').toString();
                            return GestureDetector(
                              onTap: () => _openImage(url),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: url.isEmpty
                                    ? const Center(
                                        child: Icon(Icons.image_not_supported,
                                            color: Colors.white54),
                                      )
                                    : Image.network(url, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$value',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
