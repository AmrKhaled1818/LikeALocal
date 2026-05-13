import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<PostModel> _saved = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final posts =
        await context.read<PostsProvider>().getSavedPosts(auth.uid);
    if (mounted) {
      setState(() {
        _saved = posts;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSuperUser = auth.userModel?.isSuperUser ?? false;
    final displayed = isSuperUser ? _saved : _saved.take(5).toList();
    final gated = !isSuperUser && _saved.length >= 5;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _loading ? 'Saved Posts' : 'Saved Posts (${displayed.length})',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxFeedWidth,
        child: _loading
          ? const Center(child: CircularProgressIndicator(color: kOrange))
          : CustomScrollView(
              slivers: [
                if (gated)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: kAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: kAmber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline,
                              color: kAmber, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Limit reached (5/5) — earn 100 karma to save unlimited posts',
                              style: TextStyle(
                                  color: null,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (displayed.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_border,
                              size: 64,
                              color: kMutedFg.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text('No saved posts',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text(
                              'Pin posts from the feed to save them here',
                              style: TextStyle(color: kMutedFg)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _SavedPostTile(post: displayed[i]),
                        childCount: displayed.length,
                      ),
                    ),
                  ),
              ],
            ),
        ),
    );
  }
}

class _SavedPostTile extends StatelessWidget {
  final PostModel post;
  const _SavedPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.postId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
              child: post.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: kOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.category,
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (post.isSuperUser) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star,
                              color: kAmber, size: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: kMutedFg),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            post.location,
                            style: const TextStyle(
                                color: kMutedFg, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward,
                            size: 12, color: kMutedFg),
                        Text(' ${post.upvotes}',
                            style: const TextStyle(
                                color: kMutedFg, fontSize: 11)),
                        const SizedBox(width: 10),
                        const Icon(Icons.mode_comment_outlined,
                            size: 12, color: kMutedFg),
                        Text(' ${post.commentCount}',
                            style: const TextStyle(
                                color: kMutedFg, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 35),
              child: Icon(Icons.chevron_right, color: kMutedFg, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 90,
      height: 90,
      color: kMuted,
      child: const Icon(Icons.image_outlined, color: kMutedFg, size: 28),
    );
  }
}
