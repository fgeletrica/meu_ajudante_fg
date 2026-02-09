import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../services/auth/auth_service.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String? fallbackName;
  final String? fallbackAvatar;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName,
    this.fallbackAvatar,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _sb = Supabase.instance.client;

  late final String _uid;
  bool _loading = true;
  String? _err;

  Map<String, dynamic>? _profile;
  int _followers = 0;
  int _following = 0;

  bool _isFollowing = false;

  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _uid = widget.userId.trim();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (_uid.isEmpty) return;
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      // 1) profile (VIEW public_profiles ou tabela profiles)
      Map<String, dynamic>? p;
      try {
        p = await _sb
            .from('public_profiles')
            .select('id, role, name, city, avatar_url, bio, profession')
            .eq('id', _uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        p = await _sb
            .from('profiles')
            .select('id, role, name, city, avatar_url, bio, profession')
            .eq('id', _uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 12));
      }
      _profile = p;

      // 2) counts via RPC (sem FetchOptions)
      try {
        final f1 = await _sb
            .rpc('count_followers', params: {'p_user': _uid})
            .timeout(const Duration(seconds: 12));
        final f2 = await _sb
            .rpc('count_following', params: {'p_user': _uid})
            .timeout(const Duration(seconds: 12));

        _followers = _asInt(f1);
        _following = _asInt(f2);
      } catch (_) {
        _followers = 0;
        _following = 0;
      }

      // 3) isFollowing
      final me = AuthService.user;
      if (me != null && me.id != _uid) {
        final rel = await _sb
            .from('user_follows')
            .select('follower_id')
            .eq('follower_id', me.id)
            .eq('following_id', _uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 12));
        _isFollowing = (rel != null);
      } else {
        _isFollowing = false;
      }

      // 4) posts do usuário (usa tabela posts)
      final res = await _sb
          .from('posts')
          .select('id, created_at, author_id, author_name, author_avatar_url, caption, media_url, media_type, like_count, comment_count')
          .eq('author_id', _uid)
          .order('created_at', ascending: false)
          .limit(60)
          .timeout(const Duration(seconds: 12));

      _posts = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _err = e.toString();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _toggleFollow() async {
    final me = AuthService.user;
    if (me == null || me.id == _uid) return;

    try {
      if (_isFollowing) {
        await _sb
            .from('user_follows')
            .delete()
            .eq('follower_id', me.id)
            .eq('following_id', _uid)
            .timeout(const Duration(seconds: 12));
      } else {
        await _sb
            .from('user_follows')
            .insert({'follower_id': me.id, 'following_id': _uid})
            .timeout(const Duration(seconds: 12));
      }
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao seguir: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile ?? {};
    final name = (p['name'] ?? widget.fallbackName ?? '').toString().trim();
    final city = (p['city'] ?? '').toString().trim();
    final bio = (p['bio'] ?? '').toString().trim();
    final prof = (p['profession'] ?? '').toString().trim();
    final avatar = (p['avatar_url'] ?? widget.fallbackAvatar ?? '').toString().trim();

    final me = AuthService.user;
    final isMe = me != null && me.id == _uid;

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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_err!, style: const TextStyle(color: Colors.red)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Avatar(url: avatar, size: 74),
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
                                const SizedBox(height: 4),
                                Text(
                                  [prof, city].where((x) => x.trim().isNotEmpty).join(' • '),
                                  style: TextStyle(color: Colors.white.withOpacity(.7)),
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(bio, style: TextStyle(color: Colors.white.withOpacity(.85))),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(child: _StatBox(label: 'Posts', value: _posts.length)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatBox(label: 'Seguidores', value: _followers)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatBox(label: 'Seguindo', value: _following)),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (!isMe)
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFollowing
                                  ? Colors.white.withOpacity(.12)
                                  : AppTheme.gold,
                              foregroundColor: _isFollowing ? Colors.white : Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _toggleFollow,
                            child: Text(_isFollowing ? 'Seguindo' : 'Seguir'),
                          ),
                        ),

                      const SizedBox(height: 14),

                      if (_posts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 28),
                          child: Text(
                            'Sem posts ainda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(.65)),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _posts.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemBuilder: (_, i) {
                            final it = _posts[i];
                            final url = (it['media_url'] ?? '').toString().trim();
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: url.isEmpty
                                  ? Container(color: Colors.white.withOpacity(.06))
                                  : Image.network(url, fit: BoxFit.cover),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double size;
  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    final u = url.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        color: Colors.white.withOpacity(.08),
        child: u.isEmpty
            ? Icon(Icons.person, color: Colors.white.withOpacity(.7), size: size * .55)
            : Image.network(u, fit: BoxFit.cover),
      ),
    );
  }
}
