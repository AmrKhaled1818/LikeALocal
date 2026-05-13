import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/utils/vibe_score.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';
import 'super_user_badge.dart';
import 'vibe_badge.dart';
import 'crowd_badge.dart';
import 'paywall_sheet.dart';

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
  int _imageIndex = 0;
  int _localUpvotes = 0;
  int _localDownvotes = 0;
  late final PageController _pageCtrl;

  late final AnimationController _heartCtrl;
  late final Animation<double> _heartFade;
  late final Animation<double> _heartScale;
  late final Animation<Offset> _heartSlide;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();

    _localUpvotes = widget.post.upvotes;
    _localDownvotes = widget.post.downvotes;

    _pageCtrl = PageController();
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
    if (old.post.upvotes != widget.post.upvotes) {
      setState(() => _localUpvotes = widget.post.upvotes);
    }
    if (old.post.downvotes != widget.post.downvotes) {
      setState(() => _localDownvotes = widget.post.downvotes);
    }
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
    _pageCtrl.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

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

    // Only rebuild this card when the avatar URL itself changes, not on every auth event
    final avatarUrl = context.select<AuthProvider, String>((a) =>
        (post.userId == a.uid)
            ? (a.userModel?.avatarUrl ?? post.userAvatarUrl)
            : post.userAvatarUrl);

    // Vibe Match Score — recomputes on mood change or when saved style changes.
    final mood = context.select<PostsProvider, String>((p) => p.mood);
    context.select<AuthProvider, String>((a) {
      final pr = a.userModel?.preferences ?? const {};
      return '${pr['budget']}|${pr['atmosphere']}|'
          '${(pr['favCategories'] as List?)?.join(',') ?? ''}';
    });
    final vibeScore = VibeScore.forPost(
        post, context.read<AuthProvider>().userModel?.preferences,
        mood: mood);

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
                  ? (isDark ? kAmber.withValues(alpha: 0.15) : kSuperUserBg)
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: post.isSuperUser
                    ? kAmber.withValues(alpha: 0.5)
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
                            ? CachedNetworkImageProvider(avatarUrl)
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
                                Flexible(
                                  child: Text(
                                    post.username,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
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
                      if (post.isSponsoredContent)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Sponsored',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1)),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.12),
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

                // Title + vibe match + description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: VibeBadge(score: vibeScore),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: kMutedFg, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CrowdBadge(post: post),
                      ),
                    ],
                  ),
                ),

                // Images or video indicator
                if (post.allImageUrls.isNotEmpty)
                  _buildImageSection(context, post.allImageUrls, hasVideo: post.videoUrl.isNotEmpty)
                else if (post.videoUrl.isNotEmpty)
                  _buildVideoPlaceholder(context),

                // Actions row
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      _VotePill(
                        upvotes: _localUpvotes,
                        downvotes: _localDownvotes,
                        userVote: _userVote,
                        onUpvote: () => _handleVote(1),
                        onDownvote: () => _handleVote(-1),
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

                // Tap to comment — opens detail screen (avoids N live TextFields in the feed)
                GestureDetector(
                  onTap: () => context.push('/post/${post.postId}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Row(
                      children: [
                        Builder(builder: (context) {
                          final avatar = context.select<AuthProvider, String>(
                              (a) => a.userModel?.avatarUrl ?? '');
                          final name = context.select<AuthProvider, String>(
                              (a) => a.userModel?.username ?? 'U');
                          return CircleAvatar(
                            radius: 12,
                            backgroundColor: kOrange,
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? Text(name.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10))
                                : null,
                          );
                        }),
                        const SizedBox(width: 8),
                        const Text('Add a comment...',
                            style: TextStyle(color: kMutedFg, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildVideoPlaceholder(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      height: 160,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.zero,
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white70, size: 48),
            SizedBox(height: 6),
            Text('Tap to watch video',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, List<String> urls, {bool hasVideo = false}) {
    if (urls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: urls.first,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                height: 200,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, __, ___) => Container(
                height: 200,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.image_outlined, color: kMutedFg),
              ),
            ),
            if (hasVideo)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 13),
                      SizedBox(width: 3),
                      Text('Video', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Multiple images — swipeable carousel
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Stack(
        children: [
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _imageIndex = i),
              itemBuilder: (_, i) => CachedNetworkImage(
                imageUrl: urls[i],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_outlined, color: kMutedFg),
                ),
              ),
            ),
          ),
          // Dot indicators
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
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
          // Image counter badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_imageIndex + 1}/${urls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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

    HapticFeedback.mediumImpact();

    final prevVote = _userVote;
    final voterName = auth.userModel?.username ?? '';

    if (prevVote == vote) {
      // Un-vote: remove current vote
      setState(() {
        _userVote = null;
        if (vote == 1) {
          _localUpvotes = (_localUpvotes - 1).clamp(0, 999999);
        } else {
          _localDownvotes = (_localDownvotes - 1).clamp(0, 999999);
        }
      });
      if (vote == 1) {
        posts.removeUpvote(widget.post.postId, voterName);
        AppToast.info('Upvote removed.');
      } else {
        posts.removeDownvote(widget.post.postId);
        AppToast.info('Downvote removed.');
      }
      return;
    }

    // Switch vote: undo previous, apply new
    if (prevVote == 1) {
      setState(() => _localUpvotes = (_localUpvotes - 1).clamp(0, 999999));
      posts.removeUpvote(widget.post.postId, voterName);
    } else if (prevVote == -1) {
      setState(() => _localDownvotes = (_localDownvotes - 1).clamp(0, 999999));
      posts.removeDownvote(widget.post.postId);
    }

    setState(() {
      _userVote = vote;
      if (vote == 1) {
        _localUpvotes++;
      } else {
        _localDownvotes++;
      }
    });

    if (vote == 1) {
      posts.upvotePost(widget.post.postId, auth.uid, widget.post.userId, voterName);
      AppToast.success('Upvoted!');
    } else {
      posts.downvotePost(widget.post.postId);
      AppToast.info('Downvoted.');
    }
  }

  Future<void> _handleSave() async {
    final auth = context.read<AuthProvider>();
    final posts = context.read<PostsProvider>();
    if (auth.uid.isEmpty) return;

    HapticFeedback.lightImpact();

    if (_isSaved) {
      setState(() => _isSaved = false);
      await posts.unsavePost(auth.uid, widget.post.postId);
      AppToast.info('Unpinned.');
      return;
    }

    final user = auth.userModel;
    final canSaveUnlimited =
        (user?.isSuperUser ?? false) || (user?.isPremium ?? false);
    if (!canSaveUnlimited && posts.savedPostCount >= 5) {
      await PaywallSheet.show(context, PaywallTrigger.pins);
      return;
    }

    setState(() => _isSaved = true);
    await posts.savePost(auth.uid, widget.post.postId);
    AppToast.success('Pinned!');
  }

}

class _VotePill extends StatelessWidget {
  final int upvotes;
  final int downvotes;
  final int? userVote;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  const _VotePill({
    required this.upvotes,
    required this.downvotes,
    required this.userVote,
    required this.onUpvote,
    required this.onDownvote,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.arrow_upward_rounded, upvotes, userVote == 1, kOrange, onUpvote),
          Container(width: 1, height: 14, color: kMutedFg.withValues(alpha: 0.25)),
          _btn(Icons.arrow_downward_rounded, downvotes, userVote == -1, Colors.blue, onDownvote),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, int count, bool active, Color activeColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? activeColor : kMutedFg),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? activeColor : kMutedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
