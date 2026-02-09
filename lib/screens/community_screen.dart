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
      _tab = TabController(length: _isPro ? 3 : 2, vsync: this);

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

    final tabs = _isPro
        ? const [
            Tab(icon: Icon(Icons.public), text: 'Feed'),
            Tab(icon: Icon(Icons.add_box_outlined), text: 'Postar'),
            Tab(icon: Icon(Icons.person_outline), text: 'Meu perfil'),
          ]
        : const [
            Tab(icon: Icon(Icons.public), text: 'Feed'),
            Tab(icon: Icon(Icons.person_outline), text: 'Meu perfil'),
          ];

    final views = _isPro
        ? const [
            _FeedTab(),
            _CreatePostTab(),
            _MyPostsTab(),
          ]
        : const [
            _FeedTab(),
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

  // cache de likes do usuário logado (pra ficar rápido)
  final Set<String> _liked = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
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
          .limit(60)
          .timeout(const Duration(seconds: 12));

      _items = List<Map<String, dynamic>>.from(res as List);

      // carrega likes do usuário (1 query só)
      _liked.clear();
      final u = AuthService.user;
      if (u != null && _items.isNotEmpty) {
        final ids = _items.map((e) => (e['id'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
        if (ids.isNotEmpty) {
          try {
            final likes = await _sb
                .from('post_likes')
                .select('post_id')
                .eq('user_id', u.id)
                .inFilter('post_id', ids)
                .timeout(const Duration(seconds: 12));

            for (final row in List<Map<String, dynamic>>.from(likes as List)) {
              final pid = (row['post_id'] ?? '').toString();
              if (pid.isNotEmpty) _liked.add(pid);
            }
          } catch (_) {
            // sem stress, só não marca os likes
          }
        }
      }
    } catch (e) {
      _err = (e is TimeoutException)
          ? 'Timeout ao falar com o servidor (Supabase). Verifique sua internet/DNS e tente de novo.'
          : e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLikeLocal(Map<String, dynamic> post) async {
    final u = AuthService.user;
    if (u == null) return;

    final postId = (post['id'] ?? '').toString().trim();
    if (postId.isEmpty) return;

    final already = _liked.contains(postId);

    // otimista na UI
    setState(() {
      if (already) {
        _liked.remove(postId);
        post['like_count'] = (post['like_count'] ?? 0) - 1;
        if ((post['like_count'] as int) < 0) post['like_count'] = 0;
      } else {
        _liked.add(postId);
        post['like_count'] = (post['like_count'] ?? 0) + 1;
      }
    });

    try {
      if (already) {
        await _sb
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', u.id)
            .timeout(const Duration(seconds: 12));
      } else {
        await _sb
            .from('post_likes')
            .insert({'post_id': postId, 'user_id': u.id})
            .timeout(const Duration(seconds: 12));
      }
    } catch (e) {
      // reverte se falhar
      if (!mounted) return;
      setState(() {
        if (already) {
          _liked.add(postId);
          post['like_count'] = (post['like_count'] ?? 0) + 1;
        } else {
          _liked.remove(postId);
          post['like_count'] = (post['like_count'] ?? 0) - 1;
          if ((post['like_count'] as int) < 0) post['like_count'] = 0;
        }
      });
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

  void _openComments(
    BuildContext context,
    String postId,
    String authorId,
    String authorName,
    String avatar,
  ) {
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

  void _openProfile(BuildContext context, String userId, String name, String avatar) {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

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
          'Ainda não tem posts.',
          style: TextStyle(color: Colors.white.withOpacity(.7)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final it = _items[i];

          final postId = (it['id'] ?? '').toString();
          final authorId = (it['author_id'] ?? '').toString();
          final authorName = (it['author_name'] ?? '').toString();
          final authorAvatar = (it['author_avatar_url'] ?? '').toString();

          final caption = (it['caption'] ?? '').toString();
          final mediaUrl = (it['media_url'] ?? '').toString();
          final likeCount = (it['like_count'] ?? 0) as int;
          final commentCount = (it['comment_count'] ?? 0) as int;

          final isLiked = _liked.contains(postId);

          return _IgPostCard(
            authorName: authorName.isEmpty ? 'Usuário' : authorName,
            authorAvatar: authorAvatar,
            caption: caption,
            mediaUrl: mediaUrl,
            likeCount: likeCount,
            commentCount: commentCount,
            isLiked: isLiked,
            onTapAuthor: () => _openProfile(context, authorId, authorName, authorAvatar),
            onTapAvatar: () => _openAvatarPreview(context, authorAvatar),
            onLike: () => _toggleLikeLocal(it),
            onComment: () => _openComments(context, postId, authorId, authorName, authorAvatar),
          );
        },
      ),
    );
  }
}

class _IgPostCard extends StatelessWidget {
  final String authorName;
  final String authorAvatar;
  final String caption;
  final String mediaUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final VoidCallback onTapAuthor;
  final VoidCallback onTapAvatar;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _IgPostCard({
    required this.authorName,
    required this.authorAvatar,
    required this.caption,
    required this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.onTapAuthor,
    required this.onTapAvatar,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER (avatar + nome)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onTapAvatar,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36,
                      height: 36,
                      color: Colors.white.withOpacity(.08),
                      child: authorAvatar.trim().isEmpty
                          ? Icon(Icons.person, color: Colors.white.withOpacity(.75))
                          : Image.network(authorAvatar, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onTapAuthor,
                    child: Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.more_horiz, color: Colors.white.withOpacity(.7)),
                ),
              ],
            ),
          ),

          // MÍDIA (quadrado tipo insta)
          if (mediaUrl.trim().isEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: Colors.white.withOpacity(.05),
                child: Center(
                  child: Icon(Icons.image, color: Colors.white.withOpacity(.35), size: 44),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(mediaUrl, fit: BoxFit.cover),
              ),
            ),

          const SizedBox(height: 8),

          // AÇÕES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.redAccent : Colors.white.withOpacity(.9),
                  ),
                ),
                IconButton(
                  onPressed: onComment,
                  icon: Icon(Icons.mode_comment_outlined, color: Colors.white.withOpacity(.9)),
                ),
                const Spacer(),
              ],
            ),
          ),

          // CONTAGEM
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              '$likeCount curtidas',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),

          // LEGENDA
          if (caption.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(.9), height: 1.25),
                  children: [
                    TextSpan(
                      text: authorName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: '  '),
                    TextSpan(text: caption),
                  ],
                ),
              ),
            ),

          // VER COMENTÁRIOS
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: GestureDetector(
              onTap: onComment,
              child: Text(
                commentCount <= 0 ? 'Comentar' : 'Ver $commentCount comentários',
                style: TextStyle(color: Colors.white.withOpacity(.65)),
              ),
            ),
          ),
        ],
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
