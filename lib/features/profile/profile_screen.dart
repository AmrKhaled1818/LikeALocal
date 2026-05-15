import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
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
          source: ImageSource.gallery, maxWidth: 512, imageQuality: 75);
      if (picked == null || !mounted) return;
      final auth = context.read<AuthProvider>();
      final userProvider = context.read<UserProvider>();
      AppToast.info('Uploading photo...');
      await userProvider.updateAvatar(auth.uid, picked);
      AppToast.success('Profile photo updated!');
    } catch (e) {
      AppToast.error(
          'Failed to upload photo: ${e.toString().replaceFirst("Exception: ", "")}');
    }
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

    return Scaffold(
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxDetailWidth,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              title: Text(user.username,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon:
                      const Icon(Icons.settings_outlined, color: Colors.white),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _buildProfileHeader(user)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabCtrl,
                  labelColor: kOrange,
                  unselectedLabelColor: kMutedFg,
                  indicatorColor: kOrange,
                  indicatorWeight: 2.5,
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
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final progress = (user.karma / 100).clamp(0.0, 1.0);
    final remaining = (100 - user.karma).clamp(0, 100);
    final bg = Theme.of(context).colorScheme.surface;

    return Column(
      children: [
        // ── Gradient banner + overlapping avatar ──────────────────────────
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Banner
            Container(
              height: 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kOrange, Color(0xFFD4820A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Avatar (overlaps banner bottom by half)
            Positioned(
              bottom: -44,
              child: GestureDetector(
                onTap: _editAvatar,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 4),
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: kOrange,
                        backgroundImage: user.avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatarUrl)
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
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: kOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Space for overlapping avatar
        const SizedBox(height: 54),

        // ── Username + badge ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(user.username,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            if (user.isSuperUser) ...[
              const SizedBox(width: 6),
              const SuperUserBadge(),
            ],
          ],
        ),

        // Bio
        if (user.bio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(user.bio,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMutedFg, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],

        // Location
        if (user.location.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: kMutedFg),
              const SizedBox(width: 2),
              Text(user.location,
                  style: const TextStyle(color: kMutedFg, fontSize: 12)),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // ── Stats row ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: IntrinsicHeight(
            child: Row(
              children: [
                _statCell('Posts', '${_userPosts.length}'),
                VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: kMutedFg.withValues(alpha: 0.2)),
                _statCell('Karma', '${user.karma}'),
                VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: kMutedFg.withValues(alpha: 0.2)),
                _statCell('Saved', '${_savedPosts.length}'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Edit Profile button ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileSheet(context),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kOrange,
                side: const BorderSide(color: kOrange),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Karma progress card ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kAmber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt, color: kAmber, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Karma Points',
                            style:
                                TextStyle(color: kMutedFg, fontSize: 11)),
                        Text('${user.karma} pts',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    if (user.isSuperUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: kAmber.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: kAmber, size: 13),
                            SizedBox(width: 4),
                            Text('Super User',
                                style: TextStyle(
                                    color: kAmber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ],
                        ),
                      )
                    else
                      Text('$remaining to Super',
                          style: const TextStyle(
                              color: kAmber,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: kMutedFg.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kAmber),
                    minHeight: 7,
                  ),
                ),
                if (!user.isSuperUser) ...[
                  const SizedBox(height: 6),
                  const Text('Post, upvote, and engage to earn karma!',
                      style: TextStyle(color: kMutedFg, fontSize: 11)),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: kMutedFg, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Edit Profile bottom sheet ──────────────────────────────────────────────

  void _showEditProfileSheet(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    if (user == null) return;

    final usernameCtrl = TextEditingController(text: user.username);
    final bioCtrl = TextEditingController(text: user.bio);
    final locationCtrl = TextEditingController(text: user.location);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle + title row
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: kMutedFg.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(sheetCtx),
                              style: TextButton.styleFrom(
                                  foregroundColor: kMutedFg),
                              child: const Text('Cancel'),
                            ),
                            const Expanded(
                              child: Text('Edit Profile',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(sheetCtx);
                                try {
                                  final userProvider =
                                      context.read<UserProvider>();
                                  await userProvider.updateProfile(
                                    auth.uid,
                                    username: usernameCtrl.text.trim(),
                                    bio: bioCtrl.text.trim(),
                                    location: locationCtrl.text.trim(),
                                  );
                                  AppToast.success('Profile updated!');
                                } catch (_) {
                                  AppToast.error(
                                      'Failed to update. Try again.');
                                }
                              },
                              style: TextButton.styleFrom(
                                  foregroundColor: kOrange),
                              child: const Text('Save',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      children: [
                        // Avatar section
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  Navigator.pop(sheetCtx);
                                  await _editAvatar();
                                },
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 48,
                                      backgroundColor: kOrange,
                                      backgroundImage:
                                          user.avatarUrl.isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  user.avatarUrl)
                                              : null,
                                      child: user.avatarUrl.isEmpty
                                          ? Text(
                                              user.username.isNotEmpty
                                                  ? user.username[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 34,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 2,
                                      right: 2,
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: kOrange,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white,
                                              width: 2),
                                        ),
                                        child: const Icon(Icons.camera_alt,
                                            color: Colors.white, size: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(sheetCtx);
                                  await _editAvatar();
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor: kOrange),
                                child: const Text('Change Photo',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Username
                        _sheetField(
                          label: 'Username',
                          controller: usernameCtrl,
                          icon: Icons.person_outline,
                          hint: 'Your display name',
                        ),
                        const SizedBox(height: 16),

                        // Bio
                        _sheetField(
                          label: 'Bio',
                          controller: bioCtrl,
                          icon: Icons.info_outline,
                          hint: 'A short bio about you',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Location
                        _sheetField(
                          label: 'Location',
                          controller: locationCtrl,
                          icon: Icons.location_on_outlined,
                          hint: 'Where are you based?',
                        ),

                        const SizedBox(height: 28),

                        // Save button at bottom of sheet
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(sheetCtx);
                              try {
                                final userProvider =
                                    context.read<UserProvider>();
                                await userProvider.updateProfile(
                                  auth.uid,
                                  username: usernameCtrl.text.trim(),
                                  bio: bioCtrl.text.trim(),
                                  location: locationCtrl.text.trim(),
                                );
                                AppToast.success('Profile updated!');
                              } catch (_) {
                                AppToast.error(
                                    'Failed to update. Try again.');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String hint = '',
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: kMutedFg)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: kMutedFg),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: kMutedFg.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: kMutedFg.withValues(alpha: 0.25))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kOrange, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Tab content ────────────────────────────────────────────────────────────

  Widget _buildPostsTab(List<PostModel> posts) {
    if (_loadingPosts) {
      return const Center(child: CircularProgressIndicator(color: kOrange));
    }
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.post_add_outlined,
                size: 56, color: kMutedFg.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('No posts yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
      return const Center(child: CircularProgressIndicator(color: kOrange));
    }

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
                  colors: [
                    kAmber.withValues(alpha: 0.1),
                    kOrange.withValues(alpha: 0.1)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: kAmber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: kAmber, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saved limit reached (5/5)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('Reach 100 karma to unlock unlimited saves',
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
                      size: 56, color: kMutedFg.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  const Text('No saved posts',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
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
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
          color: Theme.of(context).colorScheme.surface, child: tabBar);

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate old) => tabBar != old.tabBar;
}
