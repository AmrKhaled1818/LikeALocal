import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/posts_provider.dart';
import '../../shared/widgets/post_card.dart';

class PostsScreen extends StatelessWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        if (posts.isLoading) {
          return _buildShimmer();
        }
        return RefreshIndicator(
          color: kOrange,
          onRefresh: () async => posts.refresh(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Hidden Gems Feed',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: kDark),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Discover local spots shared by the community',
                        style: TextStyle(color: kMutedFg, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              if (posts.feedPosts.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore_outlined,
                            size: 64, color: kMutedFg.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          'No posts yet.',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'Be the first to share a hidden gem!',
                          style: TextStyle(color: kMutedFg),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: PostCard(post: posts.feedPosts[i]),
                      ),
                      childCount: posts.feedPosts.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: kMuted,
      highlightColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
