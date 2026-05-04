import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';
import '../../shared/providers/user_provider.dart';
import '../../shared/widgets/post_card.dart';
import '../../shared/widgets/super_user_badge.dart';
import '../../data/models/post_model.dart';
import '../../data/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<PostModel> _userPosts = [];
  List<PostModel> _savedPosts = [];
  bool _loadingPosts = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final postsProvider = context.read<PostsProvider>();
    if (auth.uid.isEmpty) return;

    final posts = await postsProvider.getUserPosts(auth.uid);
    final saved = await postsProvider.getSavedPosts(auth.uid);
    if (mounted) {
      setState(() {
        _userPosts = posts;
        _savedPosts = saved;
        _loadingPosts = false;
      });
    }
  }

  Future<void> _editAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          imageQuality: 75);
      if (picked == null || !mounted) return;
      final auth = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();
      await userProvider.updateAvatar(auth.uid, File(picked.path));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }

    final progress = (user.karma / 1000).clamp(0.0, 1.0);
    final remaining = (1000 - user.karma).clamp(0, 1000);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildProfileHeader(user, progress, remaining)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabCtrl,
                labelColor: kOrange,
                unselectedLabelColor: kMutedFg,
                indicatorColor: kOrange,
                tabs: [
                  Tab(text: 'My Posts (${_userPosts.length})'),
                  Tab(text: 'Saved (${_savedPosts.length})'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildPostsTab(_userPosts),
            _buildSavedTab(_savedPosts, user.isSuperUser),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, double progress, int remaining) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          GestureDetector(
            onTap: _editAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: kOrange,
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: kOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Username + badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(user.username,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDark)),
              if (user.isSuperUser) ...[
                const SizedBox(width: 8),
                const SuperUserBadge(),
              ],
            ],
          ),

          if (user.bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(user.bio,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMutedFg, fontSize: 13)),
          ],

          if (user.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: kMutedFg),
                Text(user.location,
                    style: const TextStyle(color: kMutedFg, fontSize: 12)),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Karma progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Karma Points',
                            style:
                                TextStyle(color: kMutedFg, fontSize: 12)),
                        Text(
                          '${user.karma}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kDark),
                        ),
                      ],
                    ),
                    if (!user.isSuperUser)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('To Super User',
                              style: TextStyle(
                                  color: kMutedFg, fontSize: 12)),
                          Text(
                            '$remaining pts',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kAmber),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kAmber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: kAmber, size: 14),
                            SizedBox(width: 4),
                            Text('Super User!',
                                style: TextStyle(
                                    color: kAmber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: kMutedFg.withOpacity(0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kAmber),
                    minHeight: 8,
                  ),
                ),
                if (!user.isSuperUser) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Post, upvote, and engage to earn karma!',
                    style: TextStyle(color: kMutedFg, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Edit profile button
          OutlinedButton.icon(
            onPressed: () => _showEditProfileDialog(context),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kDark,
              side: const BorderSide(color: kMutedFg),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(List<PostModel> posts) {
    if (_loadingPosts) {
      return const Center(
          child: CircularProgressIndicator(color: kOrange));
    }
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.post_add_outlined,
                size: 56, color: kMutedFg.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text('No posts yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kDark)),
            const SizedBox(height: 4),
            const Text('Share your first hidden gem!',
                style: TextStyle(color: kMutedFg)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/create'),
              child: const Text('Create Post'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PostCard(post: posts[i]),
      ),
    );
  }

  Widget _buildSavedTab(List<PostModel> saved, bool isSuperUser) {
    if (_loadingPosts) {
      return const Center(
          child: CircularProgressIndicator(color: kOrange));
    }

    // Freemium gate: max 5 saved for free users
    final gated = !isSuperUser && saved.length >= 5;
    final displayed = isSuperUser ? saved : saved.take(5).toList();

    return CustomScrollView(
      slivers: [
        if (gated)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kAmber.withOpacity(0.1), kOrange.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: kAmber, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saved limit reached (5/5)',
                            style: TextStyle(
                                color: kDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('Reach 1000 karma to unlock unlimited saves',
                            style:
                                TextStyle(color: kMutedFg, fontSize: 12)),
                      ],
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
                      size: 56, color: kMutedFg.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  const Text('No saved posts',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: kDark)),
                  const SizedBox(height: 4),
                  const Text('Pin posts to read them later',
                      style: TextStyle(color: kMutedFg)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
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
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    final usernameCtrl = TextEditingController(text: user.username);
    final bioCtrl = TextEditingController(text: user.bio);
    final locationCtrl = TextEditingController(text: user.location);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationCtrl,
                decoration:
                    const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final userProvider = context.read<UserProvider>();
              await userProvider.updateProfile(
                auth.uid,
                username: usernameCtrl.text.trim(),
                bio: bioCtrl.text.trim(),
                location: locationCtrl.text.trim(),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: tabBar);

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}
