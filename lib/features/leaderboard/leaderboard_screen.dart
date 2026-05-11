import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/user_model.dart';
import '../../shared/widgets/super_user_badge.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  Stream<List<UserModel>> _topUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('karma', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserModel.fromMap(d.data()))
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Karma Leaderboard',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ResponsiveBody(
        maxWidth: AppBreakpoints.maxFeedWidth,
        child: StreamBuilder<List<UserModel>>(
        stream: _topUsers(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load leaderboard.'));
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: kOrange));
          }
          final users = snap.data!;
          if (users.isEmpty) {
            return const Center(child: Text('No users yet.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              // Podium for top 3
              if (users.length >= 3) _Podium(users: users.take(3).toList()),
              const SizedBox(height: 24),
              // Ranked list starting at 4th place
              ...users.asMap().entries.map((e) {
                final rank = e.key + 1;
                final user = e.value;
                if (rank <= 3) return const SizedBox.shrink();
                return _LeaderboardTile(rank: rank, user: user);
              }),
            ],
          );
        },
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<UserModel> users;
  const _Podium({required this.users});

  @override
  Widget build(BuildContext context) {
    final first = users[0];
    final second = users[1];
    final third = users[2];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumSlot(rank: 2, user: second, height: 80)),
        Expanded(child: _PodiumSlot(rank: 1, user: first, height: 110)),
        Expanded(child: _PodiumSlot(rank: 3, user: third, height: 64)),
      ],
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final int rank;
  final UserModel user;
  final double height;

  const _PodiumSlot(
      {required this.rank, required this.user, required this.height});

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};
  static const _colors = {
    1: Color(0xFFFFD700),
    2: Color(0xFFC0C0C0),
    3: Color(0xFFCD7F32)
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 28,
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
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    )
                  : null,
            ),
            if (user.isSuperUser)
              const Positioned(
                right: 0,
                top: 0,
                child: SuperUserBadge(),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _medals[rank]!,
          style: const TextStyle(fontSize: 18),
        ),
        Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${user.karma} karma',
          style: TextStyle(
              color: _colors[rank]!,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: (_colors[rank]!).withOpacity(0.18),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: _colors[rank]!.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                  color: _colors[rank]!,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final UserModel user;
  const _LeaderboardTile({required this.rank, required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: kMutedFg),
            ),
          ),
          CircleAvatar(
            radius: 20,
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
                        color: Colors.white, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    if (user.isSuperUser) ...[
                      const SizedBox(width: 6),
                      const SuperUserBadge(),
                    ],
                  ],
                ),
                Text(user.location.isEmpty ? 'Explorer' : user.location,
                    style:
                        const TextStyle(color: kMutedFg, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${user.karma}',
              style: const TextStyle(
                  color: kOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
