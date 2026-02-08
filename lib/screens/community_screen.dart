import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_theme.dart';
import '../services/auth/auth_service.dart';
import '../services/avatar_cache.dart';
import 'public_profile_screen.dart';
import 'post_comments_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  final _sb = Supabase.instance.client;

  bool _loadingRole = true;
  bool _isPro = false;

  TabController? _tab;

  @override
  void initState() {
    super.initState();
    AvatarCache.init();
    _loadRoleAndTabs();
  }

  Future<void> _loadRoleAndTabs() async {
    if (!mounted) return;
    setState(() => _loadingRole = true);

    bool isPro = false;
    try {
      final r =
          await AuthService.getMyRole().timeout(const Duration(seconds: 12));
      isPro = (r == 'pro');
    } catch (_) {
      isPro = false;
    } finally {
      // garante tab controller SEMPRE
      try {
        _tab?.dispose();
      } catch (_) {}

      _isPro = isPro;
      _tab = TabController(length: 3, vsync: this);

      if (!mounted) return;
      setState(() => _loadingRole = false);
    }
  }

  @override
  void dispose() {
    try {
      _tab?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole || _tab == null) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.bg,
          elevation: 0,
          title: const Text('Comunidade'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = const [
  Tab(icon: Icon(Icons.public), text: "Feed"),
  Tab(icon: Icon(Icons.add_box_outlined), text: "Postar"),
  Tab(icon: Icon(Icons.person_outline), text: "Meu perfil"),
];

    final views = const [
  _FeedTab(),
  _CreatePostTab(),
  _MyPostsTab(),
];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: const Text('Comunidade'),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppTheme.gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(.6),
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: views,
      ),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _sb = Supabase.instance.client;

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
      final res = await _sb
          .from('posts')
          .select(
              'id, created_at, author_id, author_name, author_avatar_url, caption, media_url, media_type, like_count, comment_count')
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 12));

      _items = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _err = (e is TimeoutException)
          ? 'Timeout ao falar com o servidor (Supabase). Verifique sua internet/DNS e tente de novo.'
          : e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _isLiked(String postId) async {
    final u = AuthService.user;
    if (u == null) return false;
    final row = await _sb
        .from('post_likes')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', u.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    return row != null;
  }

  Future<void> _toggleLike(String postId) async {
    final u = AuthService.user;
    if (u == null) return;

    final liked = await _isLiked(postId).timeout(const Duration(seconds: 12));
    try {
      if (liked) {
        await _sb
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', u.id)
            .timeout(const Duration(seconds: 12));
      } else {
        await _sb
            .from('post_likes')
            .insert({'post_id': postId, 'user_id': u.id}).timeout(
                const Duration(seconds: 12));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro no like: $e')),
      );
    }
  }

  void _openAvatarPreview(BuildContext context, String url) {
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

  void _openComments(BuildContext context, String postId, String authorId,
      String authorName, String avatar) {
    final id = postId.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostCommentsScreen(
          postId: id,
          postAuthorId: authorId,
          postAuthorName: authorName,
          postAuthorAvatar: avatar,
        ),
      ),
    );
  }

  void _openProfile(
      BuildContext context, String userId, String name, String avatar) {
    final id = userId.trim();
    if (id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: id,
          fallbackName: name,
          fallbackAvatar: avatar,
        ),
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
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.85),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_err!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final it = _items[i];
          final postId = (it['id'] ?? '').toString();
          final authorId = (it['author_id'] ?? '').toString();
          final authorName = (it['author_name'] ?? '').toString();
          final avatar = (it['author_avatar_url'] ?? '').toString().trim();
          final caption = (it['caption'] ?? '').toString();
          final mediaUrl = (it['media_url'] ?? '').toString().trim();
          final likeCount = (it['like_count'] ?? 0);
          final commentCount = (it['comment_count'] ?? 0);

          if (avatar.isNotEmpty) {
            AvatarCache.rememberUserId(
                (it['author_id'] ?? '').toString(), avatar);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              AvatarCache.warm(context, avatar);
            });
          }

          return Card(
            color: AppTheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: avatar.isEmpty
                            ? null
                            : () => _openAvatarPreview(context, avatar),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withOpacity(.08),
                          backgroundImage:
                              avatar.isEmpty ? null : NetworkImage(avatar),
                          child: avatar.isEmpty
                              ? const Icon(Icons.person,
                                  size: 18, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _openProfile(
                              context, authorId, authorName, avatar),
                          child: Text(
                            authorName.isEmpty ? 'Usuário' : authorName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      _pill('❤️ $likeCount  💬 $commentCount'),
                    ],
                  ),
                  if (mediaUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          alignment: Alignment.center,
                          child: const Text('Falha ao carregar imagem'),
                        ),
                      ),
                    ),
                  ],
                  if (caption.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      caption,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.88),
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _toggleLike(postId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: AppTheme.border.withOpacity(.35)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Curtir',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openComments(
                              context, postId, authorId, authorName, avatar),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                                color: AppTheme.border.withOpacity(.35)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.mode_comment_outlined),
                          label: const Text('Comentar',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreatePostTab extends StatefulWidget {
  const _CreatePostTab();

  @override
  State<_CreatePostTab> createState() => _CreatePostTabState();
}

class _CreatePostTabState extends State<_CreatePostTab> {
  final _sb = Supabase.instance.client;
  final _caption = TextEditingController();

  bool _uploading = false;
  String? _err;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _myProfile() async {
    final u = AuthService.user;
    if (u == null) throw Exception('Usuário não logado');
    final prof = await _sb
        .from('profiles')
        .select('name, avatar_url')
        .eq('id', u.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    return (prof ?? {});
  }

  Future<void> _pickAndPost() async {
    final u = AuthService.user;
    if (u == null) return;

    setState(() {
      _uploading = true;
      _err = null;
    });

    try {
      final prof = await _myProfile().timeout(const Duration(seconds: 12));
      final name = (prof['name'] ?? '').toString();
      final avatar = (prof['avatar_url'] ?? '').toString();

      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1400,
      );
      if (picked == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }

      final Uint8List bytes = await picked.readAsBytes();
      final ext =
          picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final path = '${u.id}/post_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _sb.storage
          .from('posts')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType:
                  ext.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg',
            ),
          )
          .timeout(const Duration(seconds: 12));

      final url = _sb.storage.from('posts').getPublicUrl(path);

      await _sb.from('posts').insert({
        'author_id': u.id,
        'author_name': name,
        'author_avatar_url': avatar,
        'caption': _caption.text.trim(),
        'media_url': url,
        'media_type': 'image',
        'is_public': true,
      }).timeout(const Duration(seconds: 12));

      _caption.clear();

      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post publicado ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = (e is TimeoutException)
            ? 'Timeout ao falar com o servidor (Supabase). Verifique sua internet/DNS e tente de novo.'
            : e.toString();
        _uploading = false;
      });
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Colors.white.withOpacity(.75), fontWeight: FontWeight.w700),
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.12))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.gold.withOpacity(.65))),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border.withOpacity(.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Novo post',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _caption,
                maxLines: 3,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
                decoration: _dec('Legenda (opcional)'),
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!,
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w800)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickAndPost,
                  icon: _uploading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_library),
                  label: const Text('Escolher foto e publicar',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyPostsTab extends StatefulWidget {
  const _MyPostsTab();

  @override
  State<_MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends State<_MyPostsTab> {
  final _sb = Supabase.instance.client;

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
      final u = AuthService.user;
      if (u == null) throw Exception('Usuário não logado');

      final res = await _sb
          .from('posts')
          .select(
              'id, created_at, caption, media_url, like_count, comment_count')
          .eq('author_id', u.id)
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 12));

      _items = List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _err = (e is TimeoutException)
          ? 'Timeout ao falar com o servidor (Supabase). Verifique sua internet/DNS e tente de novo.'
          : e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_err!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Você ainda não postou.\nUse a aba “Postar”.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withOpacity(.8), fontWeight: FontWeight.w800),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final it = _items[i];
          final caption = (it['caption'] ?? '').toString();
          final mediaUrl = (it['media_url'] ?? '').toString().trim();
          final likeCount = (it['like_count'] ?? 0);
          final commentCount = (it['comment_count'] ?? 0);

          return Card(
            color: AppTheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mediaUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(mediaUrl, fit: BoxFit.cover),
                    ),
                  if (caption.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      caption,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '❤️ $likeCount   💬 $commentCount',
                    style: TextStyle(
                        color: Colors.white.withOpacity(.75),
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
