import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';
import '../../shared/widgets/post_card.dart';

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
    final posts = await context.read<PostsProvider>().getSavedPosts(auth.uid);
    if (mounted) setState(() { _saved = posts; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isSuperUser = auth.userModel?.isSuperUser ?? false;
    final gated = !isSuperUser && _saved.length >= 5;
    final displayed = isSuperUser ? _saved : _saved.take(5).toList();

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saved Posts',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    isSuperUser
                        ? '${_saved.length} saved'
                        : '${displayed.length}/5 saved — upgrade with karma to unlock more',
                    style: const TextStyle(color: kMutedFg, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          if (gated)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kAmber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, color: kAmber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reach 1000 karma to save unlimited posts',
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
                        size: 64, color: kMutedFg.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text('No saved posts',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: null)),
                    const SizedBox(height: 4),
                    const Text('Pin posts from the feed to save them here',
                        style: TextStyle(color: kMutedFg)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(post: displayed[i]),
                  ),
                  childCount: displayed.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
