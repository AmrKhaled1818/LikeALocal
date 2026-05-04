import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme/app_colors.dart';
import '../../data/models/post_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/posts_provider.dart';
import 'super_user_badge.dart';

class PostCard extends StatefulWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isSaved = false;
  int? _userVote; // 1 = up, -1 = down, null = none

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final auth = context.read<AuthProvider>();
    if (auth.uid.isEmpty) return;
    final saved = await context
        .read<PostsProvider>()
        .isPostSaved(auth.uid, widget.post.postId);
    if (mounted) setState(() => _isSaved = saved);
  }

  int get _score => widget.post.upvotes - widget.post.downvotes;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final createdAt = post.createdAt.toDate();

    return GestureDetector(
      onTap: () => context.push('/post/${post.postId}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        decoration: BoxDecoration(
          color: post.isSuperUser ? kSuperUserBg : kBackground,
          border: Border.all(
            color: post.isSuperUser ? kAmber : kMuted,
            width: post.isSuperUser ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: kOrange,
                    backgroundImage: post.userAvatarUrl.isNotEmpty
                        ? NetworkImage(post.userAvatarUrl)
                        : null,
                    child: post.userAvatarUrl.isEmpty
                        ? Text(
                            post.username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (post.isSuperUser) ...[
                              const SizedBox(width: 6),
                              const SuperUserBadge(),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: kMutedFg),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${post.location} · ${timeago.format(createdAt)}',
                                style: const TextStyle(
                                    color: kMutedFg, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Title + description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: kDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMutedFg, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Image
            if (post.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: kMuted,
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: kOrange, strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      color: kMuted,
                      child:
                          const Icon(Icons.image_outlined, color: kMutedFg),
                    ),
                  ),
                ),
              ),

            // Actions row
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  // Vote controls
                  Container(
                    decoration: BoxDecoration(
                      color: kMuted,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            size: 18,
                            color: _userVote == 1 ? kOrange : kMutedFg,
                          ),
                          onPressed: () => _handleVote(1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          constraints: const BoxConstraints(),
                        ),
                        Text(
                          _userVote == 1
                              ? '+${_score + 1}'
                              : _userVote == -1
                                  ? '+${_score - 1}'
                                  : '+$_score',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _userVote == 1
                                ? kOrange
                                : _userVote == -1
                                    ? Colors.blue
                                    : kDark,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_downward,
                            size: 18,
                            color: _userVote == -1 ? Colors.blue : kMutedFg,
                          ),
                          onPressed: () => _handleVote(-1),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Comment count
                  Row(
                    children: [
                      const Icon(Icons.mode_comment_outlined,
                          size: 16, color: kMutedFg),
                      const SizedBox(width: 4),
                      Text('${post.commentCount}',
                          style:
                              const TextStyle(color: kMutedFg, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  // Bookmark
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                      color: _isSaved ? kAmber : kMutedFg,
                      size: 20,
                    ),
                    onPressed: _handleSave,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // Share
                  IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: kMutedFg, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Link copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleVote(int vote) {
    final auth = context.read<AuthProvider>();
    final posts = context.read<PostsProvider>();
    if (auth.uid.isEmpty) return;

    if (_userVote == vote) {
      setState(() => _userVote = null);
    } else {
      if (vote == 1) {
        posts.upvotePost(
            widget.post.postId, auth.uid, widget.post.userId);
      } else {
        posts.downvotePost(widget.post.postId);
      }
      setState(() => _userVote = vote);
    }
  }

  void _handleSave() {
    final auth = context.read<AuthProvider>();
    final posts = context.read<PostsProvider>();
    if (auth.uid.isEmpty) return;

    setState(() => _isSaved = !_isSaved);
    if (_isSaved) {
      posts.savePost(auth.uid, widget.post.postId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pinned!'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      posts.unsavePost(auth.uid, widget.post.postId);
    }
  }
}
