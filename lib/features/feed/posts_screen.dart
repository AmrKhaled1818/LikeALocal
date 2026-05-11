import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/posts_provider.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/post_card.dart';

class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.extentAfter < 300) {
      context.read<PostsProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return Selector<PostsProvider, (bool, String?)>(
      selector: (_, p) => (p.isLoading, p.error),
      builder: (context, state, _) {
        final (isLoading, error) = state;
        if (isLoading) return _buildShimmer();
        if (error != null &&
            context.read<PostsProvider>().feedPosts.isEmpty) {
          return ErrorRetryWidget(
            message: error,
            onRetry: context.read<PostsProvider>().refresh,
          );
        }
        return ResponsiveBody(
          maxWidth: AppBreakpoints.maxFeedWidth,
          child: _buildFeed(context),
        );
      },
    );
  }

  Widget _buildFeed(BuildContext context) {
    return Selector<PostsProvider, (List<PostModel>, bool, bool)>(
      selector: (_, p) => (p.feedPosts, p.isLoadingMore, p.hasMore),
      builder: (context, data, _) {
        final (feedPosts, isLoadingMore, hasMore) = data;
        final posts = context.read<PostsProvider>();
        return RefreshIndicator(
          color: kOrange,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            posts.refresh();
            final completer = Completer<void>();
            void check() {
              if (!posts.isLoading) {
                posts.removeListener(check);
                if (!completer.isCompleted) completer.complete();
              }
            }
            posts.addListener(check);
            Future.delayed(const Duration(seconds: 15), () {
              if (!completer.isCompleted) completer.complete();
            });
            return completer.future;
          },
          child: CustomScrollView(
            controller: _scrollCtrl,
            cacheExtent: 500,
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hidden Gems Feed',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
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
              if (feedPosts.isEmpty)
                SliverFillRemaining(child: _EmptyFeedState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        key: ValueKey(feedPosts[i].postId),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RepaintBoundary(
                          child: PostCard(post: feedPosts[i]),
                        ),
                      ),
                      childCount: feedPosts.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: isLoadingMore
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: kOrange, strokeWidth: 2),
                          ),
                        )
                      : !hasMore && feedPosts.isNotEmpty
                          ? const Center(
                              child: Text(
                                "You've seen everything!",
                                style: TextStyle(
                                    color: kMutedFg, fontSize: 13),
                              ),
                            )
                          : const SizedBox(height: 80),
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
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kMuted),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 12,
                              width: 130,
                              color: Colors.white,
                              margin: const EdgeInsets.only(bottom: 6)),
                          Container(height: 10, width: 90, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 14,
                  width: 210,
                  color: Colors.white),
              const SizedBox(height: 8),
              Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 10,
                  color: Colors.white),
              const SizedBox(height: 4),
              Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: 10,
                  width: 160,
                  color: Colors.white),
              const SizedBox(height: 12),
              Container(height: 180, width: double.infinity, color: Colors.white),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: kOrange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.explore_outlined,
                  size: 52, color: kOrange),
            ),
            const SizedBox(height: 24),
            const Text(
              'No posts yet!',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: null),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to share a hidden gem in your city. Your local knowledge matters!',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMutedFg, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/create'),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add a Place'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
