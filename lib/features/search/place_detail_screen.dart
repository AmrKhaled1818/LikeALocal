import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/comment_model.dart';
import '../../data/models/place_group.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/posts_repo.dart';
import '../../shared/widgets/image_viewer.dart' show ImageViewerScreen;

class PlaceDetailScreen extends StatefulWidget {
  final PlaceGroup group;
  const PlaceDetailScreen({super.key, required this.group});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  int _postIndex = 0;
  late final PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  PlaceGroup get group => widget.group;

  @override
  Widget build(BuildContext context) {
    final rep = group.representative;

    return Scaffold(
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxDetailWidth,
        child: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                group.displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
              background: group.coverImageUrl.isNotEmpty
                  ? GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ImageViewerScreen(
                            imageUrl: group.coverImageUrl,
                            heroTag: 'place_cover_${group.placeKey}',
                          ),
                        ),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: group.coverImageUrl,
                        fit: BoxFit.cover,
                        color: Colors.black38,
                        colorBlendMode: BlendMode.darken,
                      ),
                    )
                  : Container(
                      color: kOrange.withValues(alpha: 0.2),
                      child: const Center(
                        child: Icon(Icons.place, size: 64, color: kOrange),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Location + category ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: kMutedFg),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          group.location,
                          style:
                              const TextStyle(color: kMutedFg, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.category,
                          style: const TextStyle(
                            color: kOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Stats chips ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _StatChip(
                        icon: Icons.description_outlined,
                        label: '${group.postCount} post${group.postCount == 1 ? '' : 's'}',
                      ),
                      _StatChip(
                        icon: Icons.arrow_upward,
                        label: '${group.totalUpvotes} upvotes',
                        color: kOrange,
                      ),
                      _StatChip(
                        icon: Icons.comment_outlined,
                        label: '${group.totalComments} reviews',
                      ),
                    ],
                  ),
                ),

                // ── Show on Map button ────────────────────────────────────────
                if (rep.lat != 0.0 && rep.lng != 0.0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.go('/map?focusPostId=${rep.postId}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Show on Map',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
                const Divider(height: 1),

                // ── Posts carousel ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    group.postCount == 1
                        ? 'Post about this place'
                        : '${group.postCount} Posts about this place',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                _PostsCarousel(
                  posts: group.posts,
                  pageCtrl: _pageCtrl,
                  currentIndex: _postIndex,
                  onPageChanged: (i) => setState(() => _postIndex = i),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1),

                // ── Community reviews ─────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Community Reviews',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                _MergedReviews(postIds: group.postIds, posts: group.posts),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Posts horizontal carousel ────────────────────────────────────────────────

class _PostsCarousel extends StatelessWidget {
  final List<PostModel> posts;
  final PageController pageCtrl;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _PostsCarousel({
    required this.posts,
    required this.pageCtrl,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: pageCtrl,
            itemCount: posts.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) => _PostCard(post: posts[i]),
          ),
        ),
        if (posts.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(posts.length, (i) {
              final active = i == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? kOrange : kMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final images = post.allImageUrls;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: images.first,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward,
                              size: 12, color: kOrange),
                          const SizedBox(width: 2),
                          Text(
                            '${post.upvotes}',
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (post.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'by ${post.username}',
                      style:
                          const TextStyle(color: kMutedFg, fontSize: 11),
                    ),
                  ],
                  if (post.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        post.description,
                        style: const TextStyle(
                            color: kMutedFg, fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/post/${post.postId}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kDark,
                  side: const BorderSide(color: kOrange),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.info_outline,
                    size: 14, color: kOrange),
                label: const Text('View Full Post',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Merged reviews (all comments from all posts, sorted newest first) ─────────

class _MergedReviews extends StatefulWidget {
  final List<String> postIds;
  final List<PostModel> posts;
  const _MergedReviews({required this.postIds, required this.posts});

  @override
  State<_MergedReviews> createState() => _MergedReviewsState();
}

class _MergedReviewsState extends State<_MergedReviews> {
  final _repo = PostsRepo();
  final Map<String, List<CommentModel>> _byPost = {};
  final List<StreamSubscription<List<CommentModel>>> _subs = [];

  @override
  void initState() {
    super.initState();
    for (final postId in widget.postIds) {
      final sub = _repo.getComments(postId).listen((comments) {
        if (mounted) setState(() => _byPost[postId] = comments);
      });
      _subs.add(sub);
    }
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  List<CommentModel> get _allComments {
    final all = _byPost.values.expand((c) => c).toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  String _postTitle(String postId) {
    try {
      return widget.posts.firstWhere((p) => p.postId == postId).title;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = _allComments;

    if (_byPost.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No reviews yet — be the first to comment!',
            style: TextStyle(color: kMutedFg),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: comments.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = comments[i];
        final fromTitle = _postTitle(c.postId);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: kOrange,
                    backgroundImage: c.userAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(c.userAvatarUrl)
                        : null,
                    child: c.userAvatarUrl.isEmpty
                        ? Text(
                            c.username.isNotEmpty
                                ? c.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.username,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (fromTitle.isNotEmpty)
                          Text(
                            'on "$fromTitle"',
                            style: const TextStyle(
                                color: kMutedFg, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatAge(c.createdAt.toDate()),
                    style:
                        const TextStyle(color: kMutedFg, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(c.content,
                  style: const TextStyle(fontSize: 13)),
              if (c.likeCount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: kMutedFg),
                    const SizedBox(width: 4),
                    Text(
                      '${c.likeCount}',
                      style: const TextStyle(
                          color: kMutedFg, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo';
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }
}

// ── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    this.color = kMutedFg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
