import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/utils/map_utils.dart';
import '../../core/utils/toast_utils.dart';
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
import '../../shared/widgets/crowd_badge.dart';
import '../../shared/widgets/paywall_sheet.dart';
import '../../core/utils/responsive.dart';
import '../../data/services/ai_service.dart';

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

  int? _userVote; // 1 = upvoted, -1 = downvoted, null = none
  bool _isSaved = false;
  bool _voteInited = false;
  bool _savedInited = false;
  int _imageIndex = 0;
  PageController? _imagePageCtrl;

  VideoPlayerController? _videoCtrl;
  String? _loadedVideoUrl;

  String _resolveAvatar(PostModel post, AuthProvider auth) {
    if (post.userId == auth.uid) {
      return auth.userModel?.avatarUrl ?? post.userAvatarUrl;
    }
    return post.userAvatarUrl;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _imagePageCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _initVideoIfNeeded(String url) {
    if (url.isEmpty || url == _loadedVideoUrl) return;
    _loadedVideoUrl = url;
    _videoCtrl?.dispose();
    _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
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
        return _buildScaffold(context, post, isOwner, auth);
      },
    );
  }

  // Called once per StreamBuilder emission to lazily set vote/save state.
  // Safe to call inside build — only writes instance fields, never calls setState.
  void _lazyInit(PostModel post, AuthProvider auth) {
    if (!_voteInited && auth.userModel != null) {
      _voteInited = true;
      if (post.upvotedBy.contains(auth.userModel!.username)) _userVote = 1;
    }
    if (!_savedInited && auth.uid.isNotEmpty) {
      _savedInited = true;
      final pp = context.read<PostsProvider>();
      if (pp.savedIdsLoaded) {
        _isSaved = pp.isPostSavedLocally(post.postId);
      } else {
        pp.loadSavedIds(auth.uid).then((_) {
          if (mounted) setState(() => _isSaved = pp.isPostSavedLocally(post.postId));
        });
      }
    }
  }

  bool _voting = false;

  Future<void> _handleVote(int vote, PostModel post, AuthProvider auth) async {
    if (_voting || auth.uid.isEmpty) return;
    _voting = true;
    HapticFeedback.mediumImpact();
    try {
      final prevVote = _userVote;
      final voterName = auth.userModel?.username ?? 'User';
      final pp = context.read<PostsProvider>();

      if (prevVote == vote) {
        // Un-vote
        setState(() => _userVote = null);
        if (vote == 1) {
          await pp.removeUpvote(post.postId, voterName);
        } else {
          await pp.removeDownvote(post.postId);
        }
        return;
      }

      // Remove previous vote before applying new one
      if (prevVote == 1) {
        await pp.removeUpvote(post.postId, voterName);
      } else if (prevVote == -1) {
        await pp.removeDownvote(post.postId);
      }

      setState(() => _userVote = vote);
      final bool ok;
      if (vote == 1) {
        ok = await pp.upvotePost(post.postId, auth.uid, post.userId, voterName);
      } else {
        ok = await pp.downvotePost(post.postId);
      }
      if (!ok && mounted) {
        setState(() => _userVote = prevVote);
        AppToast.error('Could not register vote. Try again.');
      }
    } finally {
      _voting = false;
    }
  }

  Future<void> _handleSave(AuthProvider auth, PostModel post) async {
    if (auth.uid.isEmpty) return;
    HapticFeedback.lightImpact();
    final pp = context.read<PostsProvider>();
    if (_isSaved) {
      setState(() => _isSaved = false);
      await pp.unsavePost(auth.uid, post.postId);
      AppToast.info('Unpinned.');
      return;
    }
    final u = auth.userModel;
    final canSaveUnlimited =
        (u?.isSuperUser ?? false) || (u?.isPremium ?? false);
    if (!canSaveUnlimited && pp.savedPostCount >= 5) {
      await PaywallSheet.show(context, PaywallTrigger.pins);
      return;
    }
    setState(() => _isSaved = true);
    await pp.savePost(auth.uid, post.postId);
    AppToast.success('Pinned!');
  }

  Widget _buildDetailImageSection(BuildContext context, PostModel post) {
    final urls = post.allImageUrls;
    if (urls.isEmpty) return Container(color: kMuted);
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ImageViewerScreen(imageUrl: urls.first, heroTag: post.postId),
        )),
        child: Hero(
          tag: post.postId,
          child: CachedNetworkImage(
            imageUrl: urls.first,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(color: kMuted, child: const Icon(Icons.image_outlined, color: kMutedFg)),
          ),
        ),
      );
    }

    _imagePageCtrl ??= PageController();
    return Stack(
      children: [
        PageView.builder(
          controller: _imagePageCtrl,
          itemCount: urls.length,
          onPageChanged: (i) => setState(() => _imageIndex = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ImageViewerScreen(imageUrl: urls[i], heroTag: '${post.postId}_$i'),
            )),
            child: CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: kMuted, child: const Icon(Icons.image_outlined, color: kMutedFg)),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _imageIndex == i ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _imageIndex == i ? kOrange : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Text(
              '${_imageIndex + 1}/${urls.length}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context, PostModel post, bool isOwner, AuthProvider auth) {
    _lazyInit(post, auth);
    if (post.videoUrl.isNotEmpty) _initVideoIfNeeded(post.videoUrl);
    return Scaffold(
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxDetailWidth,
        child: Column(
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
                    if (isOwner) ...[
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
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        tooltip: 'Delete post',
                        onPressed: () => _confirmDeletePost(context),
                      ),
                    ],
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
                    background: _buildDetailImageSection(context, post),
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
                              backgroundImage: _resolveAvatar(post, auth).isNotEmpty
                                  ? CachedNetworkImageProvider(_resolveAvatar(post, auth))
                                  : null,
                              backgroundColor: kOrange,
                              child: _resolveAvatar(post, auth).isEmpty
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(post.category,
                                  style: const TextStyle(
                                      color: kMutedFg, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: CrowdBadge(
                                  post: post, autoGenerate: true, dense: false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CheckInButton(postId: post.postId),
                        if (post.videoUrl.isNotEmpty && _videoCtrl != null)
                          _VideoSection(controller: _videoCtrl!),
                        const SizedBox(height: 12),

                        // ── Vote / save / time row ──────────────────────
                        Row(
                          children: [
                            // Upvote pill
                            GestureDetector(
                              onTap: () => _handleVote(1, post, auth),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _userVote == 1
                                      ? kOrange.withValues(alpha: 0.12)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _userVote == 1
                                        ? kOrange
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: _userVote == 1
                                            ? kOrange
                                            : kMutedFg),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${post.upvotes}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _userVote == 1
                                            ? kOrange
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Downvote pill
                            GestureDetector(
                              onTap: () => _handleVote(-1, post, auth),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _userVote == -1
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _userVote == -1
                                        ? Colors.blue
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: _userVote == -1
                                            ? Colors.blue
                                            : kMutedFg),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${post.downvotes}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _userVote == -1
                                            ? Colors.blue
                                            : kMutedFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Timestamp
                            Text(
                              timeago.format(post.createdAt.toDate()),
                              style: const TextStyle(
                                  color: kMutedFg, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            // Save button
                            GestureDetector(
                              onTap: () => _handleSave(auth, post),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  _isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_outline,
                                  key: ValueKey(_isSaved),
                                  color: _isSaved ? kAmber : kMutedFg,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // ────────────────────────────────────────────────

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
                                              fontSize: 14,
                                              height: 1.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF3D2B00))),
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

                        // AI Local Insight
                        const SizedBox(height: 16),
                        _LocalInsightCard(post: post),

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
                                  onPressed: () => launchDirections(context, post),
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
                        Row(
                          children: [
                            const Icon(Icons.mode_comment_outlined,
                                size: 18, color: kMutedFg),
                            const SizedBox(width: 8),
                            Text(
                              post.commentCount == 0
                                  ? 'Comments'
                                  : 'Comments (${post.commentCount})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // Comments stream
                StreamBuilder<List<CommentModel>>(
                  stream: _repo.getComments(widget.postId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                              child: CircularProgressIndicator(color: kOrange)),
                        ),
                      );
                    }
                    final comments = snap.data ?? [];
                    final topLevel =
                        comments.where((c) => c.parentId == null).toList();

                    if (topLevel.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 40, color: kMutedFg),
                                SizedBox(height: 12),
                                Text('No comments yet',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: kMutedFg)),
                                SizedBox(height: 4),
                                Text('Be the first to share your thoughts!',
                                    style: TextStyle(
                                        color: kMutedFg, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

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
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
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
      ),
    );
  }

  Future<void> _confirmDeletePost(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will permanently delete your post and all its comments. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kDestructive),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final postsProvider = context.read<PostsProvider>();
    final router = GoRouter.of(context);
    final ok = await postsProvider.deletePost(widget.postId);
    if (!mounted) return;
    if (ok) {
      AppToast.success('Post deleted.');
      router.go('/feed');
    } else {
      AppToast.error('Failed to delete post. Try again.');
    }
  }

  Future<void> _submitComment(BuildContext context) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;

    FocusScope.of(context).unfocus();
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
      AppToast.success('Comment posted! Karma +1');
    } catch (e) {
      AppToast.error('Error posting comment: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _CheckInButton extends StatefulWidget {
  final String postId;
  const _CheckInButton({required this.postId});

  @override
  State<_CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends State<_CheckInButton> {
  bool _busy = false;
  bool _done = false;

  Future<void> _checkIn() async {
    if (_busy || _done) return;
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final ok = await context
        .read<PostsProvider>()
        .checkInPost(widget.postId, auth.uid);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = ok;
    });
    if (ok) {
      AppToast.success('Checked in! Karma +1');
    } else {
      AppToast.error('Could not check in. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_busy || _done) ? null : _checkIn,
        icon: Icon(_done ? Icons.check_circle : Icons.where_to_vote_outlined,
            size: 18),
        label: Text(_done ? "You're here" : 'I\'m here now — check in'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _done ? const Color(0xFF16A34A) : kOrange,
          side: BorderSide(
              color: (_done ? const Color(0xFF16A34A) : kOrange)
                  .withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
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
            } catch (_) {
              if (context.mounted) {
                AppToast.error('Could not open chat. Check your connection.');
              }
            }
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

  Future<void> _toggleLike(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;
    final liked = widget.comment.likedBy.contains(auth.uid);
    try {
      await _repo.toggleCommentLike(
          widget.postId, widget.comment.commentId, auth.uid, !liked);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final isAuthor = widget.comment.userId == auth.uid;
    final isLiked = widget.comment.likedBy.contains(auth.uid);
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
                ? CachedNetworkImageProvider(c.userAvatarUrl)
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
                        autofocus: true,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: kMutedFg),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: kOrange),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Save', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Text(c.content,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: null)),
                // Heart reaction row
                if (!_editing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 14,
                                color: isLiked ? Colors.red : kMutedFg,
                              ),
                              if (c.likeCount > 0) ...[
                                const SizedBox(width: 3),
                                Text(
                                  '${c.likeCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isLiked ? Colors.red : kMutedFg,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isAuthor) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => setState(() => _editing = true),
                            child: const Text('Edit',
                                style: TextStyle(color: kMutedFg, fontSize: 11)),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _confirmDelete(context),
                            child: const Text('Delete',
                                style: TextStyle(color: kDestructive, fontSize: 11)),
                          ),
                        ],
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

  Future<void> _saveEdit() async {
    final text = _editCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await _repo.editComment(
          widget.postId, widget.comment.commentId, text);
      if (mounted) setState(() => _editing = false);
      AppToast.success('Comment updated.');
    } catch (e) {
      AppToast.error('Error updating comment: $e');
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
        AppToast.success('Comment deleted.');
      } catch (e) {
        AppToast.error('Error deleting comment: $e');
      }
    }
  }
}

class _LocalInsightCard extends StatefulWidget {
  final PostModel post;
  const _LocalInsightCard({required this.post});

  @override
  State<_LocalInsightCard> createState() => _LocalInsightCardState();
}

class _LocalInsightCardState extends State<_LocalInsightCard> {
  String? _summary;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.post.aiSummary.isNotEmpty) {
      _summary = widget.post.aiSummary;
    } else {
      _generate();
    }
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final result = await AIService().generatePostSummary(
        title: widget.post.title,
        category: widget.post.category,
        description: widget.post.description,
        localTips: widget.post.localTips,
      );
      if (result.isNotEmpty) {
        // Cache to Firestore so we only generate once
        await PostsRepo().updateAiSummary(widget.post.postId, result);
        if (mounted) setState(() => _summary = result);
      } else {
        if (mounted) setState(() => _error = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            const Color(0xFFEC4899).withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Text('Local Insight',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF8B5CF6))),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_summary != null)
            Text(_summary!,
                style: const TextStyle(fontSize: 13, height: 1.5))
          else if (_error)
            GestureDetector(
              onTap: _generate,
              child: const Row(
                children: [
                  Icon(Icons.refresh, size: 14, color: kMutedFg),
                  SizedBox(width: 6),
                  Text(
                    'Could not load AI response. Tap to retry.',
                    style: TextStyle(color: kMutedFg, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (!_loading)
            const Text('Generating insight...',
                style: TextStyle(color: kMutedFg, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Video player section ───────────────────────────────────────────────────

class _VideoSection extends StatefulWidget {
  final VideoPlayerController controller;
  const _VideoSection({required this.controller});

  @override
  State<_VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends State<_VideoSection> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (!ctrl.value.isInitialized) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Video',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: ctrl.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(ctrl),
                  GestureDetector(
                    onTap: () {
                      if (ctrl.value.isPlaying) {
                        ctrl.pause();
                      } else {
                        ctrl.play();
                      }
                    },
                    child: AnimatedOpacity(
                      opacity: ctrl.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(14),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          VideoProgressIndicator(
            ctrl,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: kOrange,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.black12,
            ),
          ),
        ],
      ),
    );
  }
}

