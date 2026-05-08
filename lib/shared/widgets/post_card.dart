import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';
import 'super_user_badge.dart';

const _categoryColors = {
  'restaurant': kOrange,
  'bar': Color(0xFF7C3AED),
  'café': Color(0xFF92400E),
  'cafe': Color(0xFF92400E),
  'park': Color(0xFF059669),
  'viewpoint': Color(0xFF0284C7),
  'shop': Color(0xFFDB2777),
};

Color _catColor(String category) =>
    _categoryColors[category.toLowerCase()] ?? kMutedFg;

class PostCard extends StatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  bool _isSaved = false;
  int? _userVote; // 1 = up, -1 = down, null = none

  late final AnimationController _heartCtrl;
  late final Animation<double> _heartFade;
  late final Animation<double> _heartScale;
  late final Animation<Offset> _heartSlide;
  bool _showHeart = false;

  final _commentCtrl = TextEditingController();
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();

    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _heartFade = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
            parent: _heartCtrl, curve: const Interval(0.4, 1.0)));
    _heartScale = Tween<double>(begin: 0.4, end: 1.3).animate(
        CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
    _heartSlide =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.5))
            .animate(CurvedAnimation(
                parent: _heartCtrl, curve: Curves.easeIn));
    _heartCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (mounted) setState(() => _showHeart = false);
      }
    });

    // Initialise vote state from post data (prevents reset on rebuild)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final username = auth.userModel?.username ?? '';
      if (username.isNotEmpty) {
        final voted = widget.post.upvotedBy.contains(username);
        if (voted) setState(() => _userVote = 1);
      }

      // Use local saved-IDs cache — no Firestore read per card
      final postsProvider = context.read<PostsProvider>();
      if (postsProvider.savedIdsLoaded) {
        setState(() =>
            _isSaved = postsProvider.isPostSavedLocally(widget.post.postId));
      } else if (auth.uid.isNotEmpty) {
        postsProvider.loadSavedIds(auth.uid).then((_) {
          if (mounted) {
            setState(() => _isSaved =
                postsProvider.isPostSavedLocally(widget.post.postId));
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    // Keep vote state in sync if the post data changes from provider
    if (old.post.upvotedBy != widget.post.upvotedBy) {
      final auth = context.read<AuthProvider>();
      final username = auth.userModel?.username ?? '';
      if (username.isNotEmpty) {
        final voted = widget.post.upvotedBy.contains(username);
        if (voted && _userVote != 1) setState(() => _userVote = 1);
        if (!voted && _userVote == 1) setState(() => _userVote = null);
      }
    }
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  int get _score => widget.post.upvotes - widget.post.downvotes;

  void _onDoubleTap() {
    HapticFeedback.mediumImpact();
    _handleVote(1);
    setState(() => _showHeart = true);
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final createdAt = post.createdAt.toDate();
    final catColor = _catColor(post.category);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final auth = context.watch<AuthProvider>();
    final avatarUrl = (post.userId == auth.uid)
        ? (auth.userModel?.avatarUrl ?? post.userAvatarUrl)
        : post.userAvatarUrl;

    return GestureDetector(
      onTap: () => context.push('/post/${post.postId}'),
      onDoubleTap: _onDoubleTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            decoration: BoxDecoration(
              color: post.isSuperUser
                  ? (isDark ? kAmber.withOpacity(0.15) : kSuperUserBg)
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: post.isSuperUser
                    ? kAmber.withOpacity(0.5)
                    : Theme.of(context).colorScheme.outlineVariant,
                width: post.isSuperUser ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info row + category chip
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: kOrange,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                post.username.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  post.username,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
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
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${post.location} · ${timeago.format(createdAt)}',
                                    style: const TextStyle(
                                        color: kMutedFg, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          post.category,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: catColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Title + description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: kMutedFg, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Image
                if (post.imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 200,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 200,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined,
                            color: kMutedFg),
                      ),
                    ),
                  ),

                // Actions row
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_upward,
                                size: 18,
                                color: _userVote == 1 ? kOrange : kMutedFg,
                              ),
                              onPressed: () => _handleVote(1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              constraints: const BoxConstraints(),
                            ),
                            Text(
                              '+$_score',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _userVote == 1
                                    ? kOrange
                                    : _userVote == -1
                                        ? Colors.blue
                                        : null,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_downward,
                                size: 18,
                                color: _userVote == -1
                                    ? Colors.blue
                                    : kMutedFg,
                              ),
                              onPressed: () => _handleVote(-1),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          const Icon(Icons.mode_comment_outlined,
                              size: 16, color: kMutedFg),
                          const SizedBox(width: 4),
                          Text('${post.commentCount}',
                              style: const TextStyle(
                                  color: kMutedFg, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          color: _isSaved ? kAmber : kMutedFg,
                          size: 20,
                        ),
                        onPressed: _handleSave,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: kMutedFg, size: 20),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Share.share(
                            'Check out "${post.title}" at ${post.location} on LikeALocal!',
                            subject: post.title,
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Upvoted by names
                if (post.upvotedBy.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Upvoted by ${post.upvotedBy.join(', ')}',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (post.upvotedBy.isNotEmpty) const SizedBox(height: 4),

                // "View all comments" link — no inline stream
                if (post.commentCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: GestureDetector(
                      onTap: () => context.push('/post/${post.postId}'),
                      child: Text(
                        post.commentCount > 1
                            ? 'View all ${post.commentCount} comments'
                            : 'View 1 comment',
                        style:
                            const TextStyle(color: kMutedFg, fontSize: 13),
                      ),
                    ),
                  ),

                // Inline comment input
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final avatar = auth.userModel?.avatarUrl ?? '';
                          final name = auth.userModel?.username ?? 'U';
                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: kOrange,
                            backgroundImage: avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? Text(
                                    name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10))
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurface,
                              fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle:
                                TextStyle(color: kMutedFg, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (val) => _submitComment(val),
                        ),
                      ),
                      if (_submittingComment)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kOrange),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // Double-tap heart overlay
          if (_showHeart)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: SlideTransition(
                    position: _heartSlide,
                    child: FadeTransition(
                      opacity: _heartFade,
                      child: ScaleTransition(
                        scale: _heartScale,
                        child: const Icon(
                          Icons.favorite,
                          color: kOrange,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleVote(int vote) {
    final auth = context.read<AuthProvider>();
    final posts = context.read<PostsProvider>();
    if (auth.uid.isEmpty) return;

    if (_userVote == vote) {
      setState(() => _userVote = null);
      return; // un-vote — local state only, no Firestore call
    }

    HapticFeedback.mediumImpact();
    if (vote == 1) {
      posts.upvotePost(
          widget.post.postId,
          auth.uid,
          widget.post.userId,
          auth.userModel?.username ?? 'User');
    } else {
      posts.downvotePost(widget.post.postId);
    }
    setState(() => _userVote = vote);
  }

  Future<void> _handleSave() async {
    final auth = context.read<AuthProvider>();
    final posts = context.read<PostsProvider>();
    if (auth.uid.isEmpty) return;

    HapticFeedback.lightImpact();

    if (_isSaved) {
      setState(() => _isSaved = false);
      await posts.unsavePost(auth.uid, widget.post.postId);
      return;
    }

    final isSuperUser = auth.userModel?.isSuperUser ?? false;
    if (!isSuperUser) {
      // Use the local cache count to check the limit
      final savedPosts = await posts.getSavedPosts(auth.uid);
      if (!mounted) return;
      if (savedPosts.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Save limit reached (5/5). Unsave a post or earn 100 karma to unlock unlimited saves.'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() => _isSaved = true);
    await posts.savePost(auth.uid, widget.post.postId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pinned!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _submitComment(String text) async {
    if (text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;

    setState(() => _submittingComment = true);
    try {
      final comment = CommentModel(
        commentId: '',
        postId: widget.post.postId,
        userId: auth.uid,
        username: auth.userModel?.username ?? 'User',
        userAvatarUrl: auth.userModel?.avatarUrl ?? '',
        isSuperUser: auth.userModel?.isSuperUser ?? false,
        content: text.trim(),
      );
      await context.read<PostsProvider>().addComment(comment);
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }
}
