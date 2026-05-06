import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/posts_repo.dart';
import '../../data/repositories/chat_repo.dart';
import '../../features/edit/edit_post_screen.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/providers/posts_provider.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/image_viewer.dart';
import '../../shared/widgets/super_user_badge.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostsRepo _repo = PostsRepo();
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return StreamBuilder<PostModel?>(
      stream: _repo.watchPost(widget.postId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorRetryWidget(
              message: 'Could not load post. Check your connection.',
              onRetry: () => setState(() {}),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator(color: kOrange)),
          );
        }

        final post = snap.data!;
        final isOwner = post.userId == auth.uid;
        return _buildScaffold(context, post, isOwner);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, PostModel post, bool isOwner) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Hero image app bar
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  actions: [
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white),
                        tooltip: 'Edit post',
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPostScreen(post: post),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white),
                      onPressed: () => Share.share(
                        'Check out "${post.title}" at ${post.location} on LikeALocal!',
                        subject: post.title,
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: post.imageUrl.isNotEmpty
                        ? GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageViewerScreen(
                                  imageUrl: post.imageUrl,
                                  heroTag: post.postId,
                                ),
                              ),
                            ),
                            child: Hero(
                              tag: post.postId,
                              child: CachedNetworkImage(
                                imageUrl: post.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                    color: kMuted,
                                    child: const Icon(Icons.image_outlined,
                                        color: kMutedFg)),
                              ),
                            ),
                          )
                        : Container(color: kMuted),
                  ),
                ),

                // Post content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: post.userAvatarUrl.isNotEmpty
                                  ? NetworkImage(post.userAvatarUrl)
                                  : null,
                              backgroundColor: kOrange,
                              child: post.userAvatarUrl.isEmpty
                                  ? Text(
                                      post.username
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(post.username,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    if (post.isSuperUser) ...[
                                      const SizedBox(width: 6),
                                      const SuperUserBadge(),
                                    ],
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 12, color: kMutedFg),
                                    Text(post.location,
                                        style: const TextStyle(
                                            color: kMutedFg, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            _MessageOwnerButton(post: post),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(post.title,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: null)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: kMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(post.category,
                              style: const TextStyle(
                                  color: kMutedFg, fontSize: 12)),
                        ),
                        const SizedBox(height: 12),
                        Text(post.description,
                            style: const TextStyle(
                                color: null, fontSize: 14, height: 1.5)),
                        if (post.localTips.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kSuperUserBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: kAmber, width: 0.5),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.tips_and_updates_outlined,
                                    color: kAmber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Local Tips',
                                          style: TextStyle(
                                              color: kAmber,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text(post.localTips,
                                          style: const TextStyle(
                                              fontSize: 13, color: null)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (post.recommendedDishes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Recommended Dishes',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: post.recommendedDishes
                                .map((d) => Chip(
                                      label: Text(d,
                                          style: const TextStyle(
                                              fontSize: 12)),
                                      backgroundColor: kMuted,
                                      side: BorderSide.none,
                                    ))
                                .toList(),
                          ),
                        ],

                        // Show on Map button
                        if (post.lat != 0 && post.lng != 0) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => context.go('/map?focusPostId=${post.postId}'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kOrange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.map_outlined, size: 18),
                                  label: const Text('Show on Map',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final url = Uri.parse(
                                      'https://www.google.com/maps/dir/?api=1'
                                      '&destination=${Uri.encodeComponent('${post.title}, ${post.location}')}'
                                      '&travelmode=driving',
                                    );
                                    try {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    } catch (_) {
                                      try {
                                        await launchUrl(url, mode: LaunchMode.platformDefault);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Could not open maps. Fully restart the app.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A73E8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.directions, size: 18),
                                  label: const Text('Get Directions',
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(),
                        const Text('Comments',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16, color: null)),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Comments stream
                StreamBuilder<List<CommentModel>>(
                  stream: _repo.getComments(widget.postId),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Center(
                            child: CircularProgressIndicator(color: kOrange)),
                      );
                    }
                    final comments = snap.data!;
                    final topLevel =
                        comments.where((c) => c.parentId == null).toList();
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final comment = topLevel[i];
                          final replies = comments
                              .where(
                                  (c) => c.parentId == comment.commentId)
                              .toList();
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Column(
                              children: [
                                _CommentItem(
                                    comment: comment, postId: post.postId),
                                ...replies.map((r) => Padding(
                                      padding:
                                          const EdgeInsets.only(left: 32),
                                      child: _CommentItem(
                                          comment: r, postId: post.postId),
                                    )),
                              ],
                            ),
                          );
                        },
                        childCount: topLevel.length,
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              top: 8,
            ),
            decoration: const BoxDecoration(
              color: kBackground,
              border: Border(top: BorderSide(color: kMuted)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _submitting
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            color: kOrange, strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.send, color: kOrange),
                        onPressed: () => _submitComment(context),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment(BuildContext context) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final comment = CommentModel(
        commentId: '',
        postId: widget.postId,
        userId: auth.uid,
        username: auth.userModel?.username ?? 'User',
        userAvatarUrl: auth.userModel?.avatarUrl ?? '',
        isSuperUser: auth.userModel?.isSuperUser ?? false,
        content: text,
      );
      await context.read<PostsProvider>().addComment(comment);
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: kDestructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _MessageOwnerButton extends StatelessWidget {
  final PostModel post;

  const _MessageOwnerButton({required this.post});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (post.userId == auth.uid) return const SizedBox.shrink();

    return FutureBuilder<bool>(
      future: context
          .read<UserProvider>()
          .getUser(post.userId)
          .then((u) => u?.chatEnabled ?? false),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return TextButton.icon(
          onPressed: () async {
            try {
              final chatId = await ChatRepo()
                  .getOrCreateChat(auth.uid, post.userId);
              if (context.mounted) {
                context.push('/conversation/$chatId');
              }
            } catch (_) {}
          },
          icon: const Icon(Icons.message_outlined, size: 16),
          label: const Text('Message', style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(foregroundColor: kOrange),
        );
      },
    );
  }
}

class _CommentItem extends StatefulWidget {
  final CommentModel comment;
  final String postId;

  const _CommentItem({required this.comment, required this.postId});

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  final PostsRepo _repo = PostsRepo();
  bool _editing = false;
  final _editCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editCtrl.text = widget.comment.content;
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isAuthor = widget.comment.userId == auth.uid;
    final c = widget.comment;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: kOrange,
            backgroundImage: c.userAvatarUrl.isNotEmpty
                ? NetworkImage(c.userAvatarUrl)
                : null,
            child: c.userAvatarUrl.isEmpty
                ? Text(c.username.substring(0, 1).toUpperCase(),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13, color: null)),
                    if (c.isSuperUser) ...[
                      const SizedBox(width: 4),
                      const SuperUserBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(timeago.format(c.createdAt.toDate()),
                        style: const TextStyle(
                            color: kMutedFg, fontSize: 11)),
                    if (c.editedAt != null)
                      const Text(' (edited)',
                          style: TextStyle(
                              color: kMutedFg,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                  ],
                ),
                const SizedBox(height: 2),
                if (_editing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextField(
                        controller: _editCtrl,
                        maxLines: null,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _editing = false),
                            child: const Text('Cancel',
                                style: TextStyle(color: kMutedFg)),
                          ),
                          ElevatedButton(
                            onPressed: _saveEdit,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Text(c.content,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: null)),
              ],
            ),
          ),
          if (isAuthor && !_editing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: kMutedFg),
              onSelected: (val) {
                if (val == 'edit') setState(() => _editing = true);
                if (val == 'delete') _confirmDelete(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete',
                      style: TextStyle(color: kDestructive)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _saveEdit() async {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await _repo.editComment(
          widget.postId, widget.comment.commentId, text);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: kDestructive),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete comment?'),
        content:
            const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kDestructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await _repo.deleteComment(widget.postId, widget.comment.commentId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'),
                backgroundColor: kDestructive),
          );
        }
      }
    }
  }
}

