import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/place_group.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/user_repo.dart';
import '../../data/models/user_model.dart';
import '../../shared/providers/posts_provider.dart';
import '../../core/utils/responsive.dart';
import '../../shared/widgets/post_card.dart';
import 'place_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  late TabController _tabCtrl;
  String _query = '';
  bool _searching = false;
  bool _showSuggestions = false;
  List<UserModel> _userResults = [];
  List<String> _recentSearches = [];
  String _selectedCategory = 'All';

  static const _categories = [
    'All', 'Restaurant', 'Bar', 'Café', 'Park', 'Viewpoint', 'Shop'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadRecentSearches();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _recentSearches = prefs.getStringList('search_recent') ?? [];
      });
    }
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('search_recent') ?? [];
    list.remove(query);
    list.insert(0, query);
    if (list.length > 10) list.removeLast();
    await prefs.setStringList('search_recent', list);
    if (mounted) setState(() => _recentSearches = list);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_recent');
    if (mounted) setState(() => _recentSearches = []);
  }

  bool _matchesPost(PostModel p, String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'));
    final haystack =
        '${p.title} ${p.location} ${p.description} ${p.category} ${p.localTips} ${p.recommendedDishes.join(' ')}'
            .toLowerCase();
    final catOk = _selectedCategory == 'All' ||
        p.category.toLowerCase() == _selectedCategory.toLowerCase() ||
        (_selectedCategory == 'Café' &&
            (p.category == 'Café' || p.category == 'Cafe'));
    return catOk && words.every((w) => haystack.contains(w));
  }

  List<PostModel> _getSuggestions(List<PostModel> allPosts) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return [];
    final seen = <String>{};
    final results = <PostModel>[];
    for (final p in allPosts) {
      if (seen.contains(p.postId)) continue;
      if (p.title.toLowerCase().startsWith(q) ||
          p.location.toLowerCase().startsWith(q) ||
          p.title.toLowerCase().contains(q) ||
          p.location.toLowerCase().contains(q)) {
        seen.add(p.postId);
        results.add(p);
      }
      if (results.length >= 7) break;
    }
    results.sort((a, b) {
      final aS = a.title.toLowerCase().startsWith(q) ? 0 : 1;
      final bS = b.title.toLowerCase().startsWith(q) ? 0 : 1;
      return aS.compareTo(bS);
    });
    return results;
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _query = '';
        _userResults = [];
        _searching = false;
        _showSuggestions = false;
      });
      return;
    }
    setState(() {
      _query = q.trim();
      _searching = true;
      _showSuggestions = false;
    });
    await _addRecentSearch(q.trim());
    try {
      final users = await UserRepo().searchUsers(_query);
      if (mounted) setState(() => _userResults = users);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        setState(() => _showSuggestions = false);
      },
      child: Scaffold(
        body: SafeArea(
          child: ResponsiveBody(
            maxWidth: AppBreakpoints.maxFeedWidth,
            child: Column(
              children: [
                _buildSearchHeader(),
                if (_query.isNotEmpty) _buildTabs(),
                Expanded(
                  child: _query.isEmpty
                      ? _buildDiscovery()
                      : _buildResults(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explore',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Consumer<PostsProvider>(builder: (_, postsP, __) {
            final suggestions = _showSuggestions ? _getSuggestions(postsP.feedPosts) : <PostModel>[];
            return Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  onChanged: (v) => setState(() {
                    _showSuggestions = v.isNotEmpty && _focusNode.hasFocus;
                  }),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _runSearch(v.trim());
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: kMutedFg, size: 20),
                    hintText: 'Search posts, places, people, categories...',
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, color: kMutedFg, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _runSearch('');
                              setState(() => _showSuggestions = false);
                            },
                          )
                        : null,
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kMuted),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: suggestions.map((post) {
                        return InkWell(
                          onTap: () {
                            _focusNode.unfocus();
                            setState(() => _showSuggestions = false);
                            context.push('/post/${post.postId}');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.place, color: kOrange, size: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        post.location,
                                        style: const TextStyle(
                                            color: kMutedFg, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
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
                                        color: kOrange, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    ),
                  ),
                  ),
                ],
              ],
            );
          }),
          const SizedBox(height: 8),
          // Category chips
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? kOrange : kMuted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : kMutedFg,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabCtrl,
      labelColor: kOrange,
      unselectedLabelColor: kMutedFg,
      indicatorColor: kOrange,
      tabs: const [
        Tab(text: 'Places'),
        Tab(text: 'Posts'),
        Tab(text: 'People'),
      ],
    );
  }

  bool _categoryMatches(PostModel p) {
    if (_selectedCategory == 'All') return true;
    return p.category.toLowerCase() == _selectedCategory.toLowerCase() ||
        (_selectedCategory == 'Café' &&
            (p.category == 'Café' || p.category == 'Cafe'));
  }

  Widget _buildDiscovery() {
    return Consumer<PostsProvider>(
      builder: (context, postsProvider, _) {
        final allPosts = _selectedCategory == 'All'
            ? postsProvider.feedPosts
            : postsProvider.feedPosts.where(_categoryMatches).toList();

        // Trending = top 5 by upvotes (filtered by selected category)
        final trending = List<PostModel>.from(allPosts)
          ..sort((a, b) => b.upvotes.compareTo(a.upvotes));
        final trendingList = trending.take(5).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trending',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (trendingList.isEmpty)
                Text(
                  _selectedCategory == 'All'
                      ? 'No posts yet'
                      : 'No trending $_selectedCategory spots yet',
                  style: const TextStyle(color: kMutedFg, fontSize: 13),
                )
              else
                ...trendingList.asMap().entries.map((e) {
                  final p = e.value;
                  final rank = e.key + 1;
                  return ListTile(
                    onTap: () {
                      _searchCtrl.text = p.title;
                      _runSearch(p.title);
                    },
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? kOrange.withValues(alpha: 0.1)
                            : kMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: rank <= 3 ? kOrange : kMutedFg,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    title: Text(p.title,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.location,
                        style:
                            const TextStyle(color: kMutedFg, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_upward,
                            color: kOrange, size: 14),
                        const SizedBox(width: 2),
                        Text('${p.upvotes}',
                            style: const TextStyle(
                                color: kOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    dense: true,
                  );
                }),

              if (_recentSearches.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Recent',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearRecentSearches,
                      child: const Text('Clear',
                          style: TextStyle(color: kOrange, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._recentSearches.map((r) => ListTile(
                      leading: const Icon(Icons.history,
                          color: kMutedFg, size: 20),
                      title: Text(r,
                          style: const TextStyle(fontSize: 14)),
                      trailing: GestureDetector(
                        onTap: () async {
                          final prefs =
                              await SharedPreferences.getInstance();
                          final list = prefs.getStringList('search_recent') ??
                              [];
                          list.remove(r);
                          await prefs.setStringList('search_recent', list);
                          if (mounted) {
                            setState(() => _recentSearches = list);
                          }
                        },
                        child: const Icon(Icons.close,
                            color: kMutedFg, size: 16),
                      ),
                      onTap: () {
                        _searchCtrl.text = r;
                        _runSearch(r);
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    )),
              ],

              const SizedBox(height: 20),
              Text(
                _selectedCategory == 'All'
                    ? 'Recommended For You'
                    : 'Top $_selectedCategory Spots',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _RecommendedSection(category: _selectedCategory),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _PlaceResults(
            query: _query,
            matcher: _matchesPost,
            selectedCategory: _selectedCategory),
        _PostResults(query: _query, matcher: _matchesPost),
        _PeopleResults(users: _userResults, searching: _searching),
      ],
    );
  }
}

// ── Place results (grouped by place) ─────────────────────────────────────────

class _PlaceResults extends StatelessWidget {
  final String query;
  final bool Function(PostModel, String) matcher;
  final String selectedCategory;

  const _PlaceResults({
    required this.query,
    required this.matcher,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final matched = posts.feedPosts.where((p) => matcher(p, query)).toList();

        if (matched.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined,
                    size: 56, color: kMutedFg.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  selectedCategory == 'All'
                      ? 'No places found for "$query"'
                      : 'No $selectedCategory places found for "$query"',
                  style: const TextStyle(color: kMutedFg),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text('Try searching by name, area, or category',
                    style: TextStyle(color: kMutedFg, fontSize: 12)),
              ],
            ),
          );
        }

        final groups = PlaceGroup.groupPosts(matched);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (_, i) => _PlaceGroupCard(group: groups[i]),
        );
      },
    );
  }
}

// ── Place group card ──────────────────────────────────────────────────────────

class _PlaceGroupCard extends StatelessWidget {
  final PlaceGroup group;
  const _PlaceGroupCard({required this.group});

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(group: group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rep = group.representative;
    final coverUrl = group.coverImageUrl;
    final hasMultiple = group.postCount > 1;

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (coverUrl.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: CachedNetworkImage(
                      imageUrl: coverUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        height: 130,
                        color: kMuted,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: kMutedFg),
                      ),
                    ),
                  ),
                  if (hasMultiple)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${group.postCount} posts',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),

            // Title + location + category
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.place, color: kOrange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.displayTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: kMutedFg),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                group.location,
                                style: const TextStyle(
                                    color: kMutedFg, fontSize: 12),
                                maxLines: 1,
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
                      color: kOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      group.category,
                      style: const TextStyle(
                          color: kOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(
                children: [
                  const Icon(Icons.arrow_upward,
                      size: 13, color: kOrange),
                  const SizedBox(width: 3),
                  Text(
                    '${group.totalUpvotes}',
                    style: const TextStyle(
                        color: kOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.comment_outlined,
                      size: 13, color: kMutedFg),
                  const SizedBox(width: 3),
                  Text(
                    '${group.totalComments} reviews',
                    style: const TextStyle(
                        color: kMutedFg, fontSize: 12),
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.people_outline,
                        size: 13, color: kMutedFg),
                    const SizedBox(width: 3),
                    Text(
                      '${group.postCount} locals posted',
                      style: const TextStyle(
                          color: kMutedFg, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),

            // Description from representative post
            if (rep.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(
                  rep.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMutedFg, fontSize: 13),
                ),
              ),

            // Tip
            if (rep.localTips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 13, color: kAmber),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        rep.localTips,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: kMutedFg,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.go('/map?focusPostId=${rep.postId}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Show on Map',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetail(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kDark,
                        side: const BorderSide(color: kOrange),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.reviews_outlined,
                          size: 16, color: kOrange),
                      label: Text(
                        hasMultiple ? 'All Reviews' : 'View Details',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recommended section ──────────────────────────────────────────────────────

class _RecommendedSection extends StatelessWidget {
  final String category;
  const _RecommendedSection({required this.category});

  bool _matches(PostModel p) {
    if (category == 'All') return true;
    return p.category.toLowerCase() == category.toLowerCase() ||
        (category == 'Café' && (p.category == 'Café' || p.category == 'Cafe'));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final recommended =
            posts.feedPosts.where(_matches).take(3).toList();
        if (recommended.isEmpty) {
          return Text(
            category == 'All'
                ? 'Explore posts to get recommendations'
                : 'No $category spots found yet',
            style: const TextStyle(color: kMutedFg, fontSize: 13),
          );
        }
        return Column(
          children: recommended
              .map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(post: p),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Post results ─────────────────────────────────────────────────────────────

class _PostResults extends StatelessWidget {
  final String query;
  final bool Function(PostModel, String) matcher;
  const _PostResults({required this.query, required this.matcher});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final results =
            posts.feedPosts.where((p) => matcher(p, query)).toList();
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off,
                    size: 56, color: kMutedFg.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('No posts found for "$query"',
                    style: const TextStyle(color: kMutedFg)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(post: results[i]),
          ),
        );
      },
    );
  }
}

// ── People results ────────────────────────────────────────────────────────────

class _PeopleResults extends StatelessWidget {
  final List<UserModel> users;
  final bool searching;
  const _PeopleResults({required this.users, required this.searching});

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator(color: kOrange));
    }
    if (users.isEmpty) {
      return const Center(
          child: Text('No users found', style: TextStyle(color: kMutedFg)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final user = users[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(user.avatarUrl)
                : null,
            backgroundColor: kOrange,
            child: user.avatarUrl.isEmpty
                ? Text(user.username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white))
                : null,
          ),
          title: Text(user.username,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('Karma: ${user.karma}',
              style: const TextStyle(color: kMutedFg, fontSize: 12)),
          trailing: user.isSuperUser
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Super User',
                      style: TextStyle(
                          color: kAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                )
              : null,
        );
      },
    );
  }
}
