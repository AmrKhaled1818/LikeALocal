import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/user_repo.dart';
import '../../data/models/user_model.dart';
import '../../shared/providers/posts_provider.dart';
import '../../shared/widgets/post_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;
  String _query = '';
  bool _searching = false;
  List<UserModel> _userResults = [];

  static const _trending = [
    'Hidden cafes Cairo',
    'Street art spots',
    'Rooftop restaurants',
    'Night markets',
    'Local bookstores',
  ];

  static const _recentSearches = [
    'Zamalek coffee',
    'Maadi parks',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _query = '';
        _userResults = [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _query = q.trim();
      _searching = true;
    });
    try {
      final users = await UserRepo().searchUsers(_query);
      if (mounted) setState(() => _userResults = users);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
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
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: kDark),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: _runSearch,
            decoration: InputDecoration(
              prefixIcon:
                  const Icon(Icons.search, color: kMutedFg, size: 20),
              hintText: 'Search posts, people, places...',
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, color: kMutedFg, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _runSearch('');
                      },
                    )
                  : null,
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
        Tab(text: 'Posts'),
        Tab(text: 'People'),
      ],
    );
  }

  Widget _buildDiscovery() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trending',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: kDark),
          ),
          const SizedBox(height: 10),
          ..._trending.asMap().entries.map((e) => _TrendingTile(
                rank: e.key + 1,
                text: e.value,
                onTap: () {
                  _searchCtrl.text = e.value;
                  _runSearch(e.value);
                },
              )),
          if (_recentSearches.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Recent',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: kDark),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: const Text('Clear',
                      style: TextStyle(color: kOrange, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._recentSearches.map((r) => ListTile(
                  leading:
                      const Icon(Icons.history, color: kMutedFg, size: 20),
                  title: Text(r,
                      style:
                          const TextStyle(fontSize: 14, color: kDark)),
                  onTap: () {
                    _searchCtrl.text = r;
                    _runSearch(r);
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
          ],
          const SizedBox(height: 20),
          const Text(
            'Recommended For You',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: kDark),
          ),
          const SizedBox(height: 10),
          _RecommendedSection(),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _PostResults(query: _query),
        _PeopleResults(
          users: _userResults,
          searching: _searching,
        ),
      ],
    );
  }
}

class _TrendingTile extends StatelessWidget {
  final int rank;
  final String text;
  final VoidCallback onTap;

  const _TrendingTile(
      {required this.rank, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: rank <= 3 ? kOrange.withOpacity(0.1) : kMuted,
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
      title: Text(text,
          style: const TextStyle(fontSize: 14, color: kDark)),
      trailing:
          const Icon(Icons.trending_up, color: kMutedFg, size: 16),
      dense: true,
    );
  }
}

class _RecommendedSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final recommended = posts.feedPosts.take(3).toList();
        if (recommended.isEmpty) {
          return const Text('Explore posts to get recommendations',
              style: TextStyle(color: kMutedFg, fontSize: 13));
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

class _PostResults extends StatelessWidget {
  final String query;
  const _PostResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, posts, _) {
        final results = posts.feedPosts
            .where((p) =>
                p.title.toLowerCase().contains(query.toLowerCase()) ||
                p.location.toLowerCase().contains(query.toLowerCase()) ||
                p.description.toLowerCase().contains(query.toLowerCase()))
            .toList();

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off,
                    size: 56, color: kMutedFg.withOpacity(0.4)),
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

class _PeopleResults extends StatelessWidget {
  final List<UserModel> users;
  final bool searching;

  const _PeopleResults({required this.users, required this.searching});

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(
          child: CircularProgressIndicator(color: kOrange));
    }
    if (users.isEmpty) {
      return const Center(
        child: Text('No users found',
            style: TextStyle(color: kMutedFg)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final user = users[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatarUrl.isNotEmpty
                ? NetworkImage(user.avatarUrl)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kAmber.withOpacity(0.15),
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
