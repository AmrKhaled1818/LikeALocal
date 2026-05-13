import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repo.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';

class FriendsSidebar extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const FriendsSidebar(
      {super.key, required this.isOpen, required this.onClose});

  @override
  State<FriendsSidebar> createState() => _FriendsSidebarState();
}

class _FriendsSidebarState extends State<FriendsSidebar> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onClose,
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {}, // prevent close on sidebar tap
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          children: [
                            const Text('Friends',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                      ),
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          decoration: const InputDecoration(
                            prefixIcon:
                                Icon(Icons.search, color: kMutedFg, size: 20),
                            hintText: 'Search users by username...',
                          ),
                        ),
                      ),

                      // Live search results
                      if (_query.isNotEmpty)
                        _UserSearchResults(
                          query: _query,
                          onClose: widget.onClose,
                        )
                      else
                        _ExistingChats(onClose: widget.onClose),

                      const Spacer(),
                      // Add friend
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton.icon(
                          onPressed: () => _showAddFriend(context),
                          icon: const Icon(Icons.person_add_outlined,
                              color: kOrange),
                          label: const Text('Add Friend',
                              style: TextStyle(color: kOrange)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }

  void _showAddFriend(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Find Friend'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Enter exact username'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final username = ctrl.text.trim();
              if (username.isEmpty) return;
              Navigator.pop(ctx);
              await _startChatWithUsername(username);
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _startChatWithUsername(String username) async {
    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    // Search Firestore for user with this username
    final users = await UserRepo().searchUsers(username);
    final match = users.firstWhere(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
      orElse: () => UserModel(uid: '', username: ''),
    );

    if (!mounted) return;

    if (match.uid.isEmpty) {
      AppToast.error('User "$username" not found');
      return;
    }

    if (match.uid == auth.uid) {
      AppToast.warning("You can't chat with yourself!");
      return;
    }

    final chatId =
        await chatProvider.getOrCreateChat(auth.uid, match.uid);
    if (!mounted) return;
    if (chatId == null) {
      AppToast.error('Could not open chat. Check your connection.');
      return;
    }
    widget.onClose();
    context.push('/conversation/$chatId');
  }
}

/// Shows live search results from Firestore
class _UserSearchResults extends StatefulWidget {
  final String query;
  final VoidCallback onClose;
  const _UserSearchResults({required this.query, required this.onClose});

  @override
  State<_UserSearchResults> createState() => _UserSearchResultsState();
}

class _UserSearchResultsState extends State<_UserSearchResults> {
  List<UserModel> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_UserSearchResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final results = await UserRepo().searchUsers(widget.query);
      if (mounted) setState(() => _results = results);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: kOrange)),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No users found for "${widget.query}"',
            style: const TextStyle(color: kMutedFg)),
      );
    }
    return Expanded(
      child: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (_, i) {
          final u = _results[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: kOrange,
              backgroundImage:
                  u.avatarUrl.isNotEmpty ? CachedNetworkImageProvider(u.avatarUrl) : null,
              child: u.avatarUrl.isEmpty
                  ? Text(u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white))
                  : null,
            ),
            title: Text(u.username,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: u.location.isNotEmpty
                ? Text(u.location,
                    style: const TextStyle(color: kMutedFg, fontSize: 12))
                : null,
            trailing: const Icon(Icons.chat_bubble_outline,
                color: kOrange, size: 20),
            onTap: () async {
              final auth = context.read<AuthProvider>();
              final chatProvider = context.read<ChatProvider>();
              if (u.uid == auth.uid) {
                AppToast.warning("You can't chat with yourself!");
                return;
              }
              final chatId =
                  await chatProvider.getOrCreateChat(auth.uid, u.uid);
              if (!context.mounted) return;
              if (chatId == null) {
                AppToast.error('Could not open chat. Check your connection.');
                return;
              }
              widget.onClose();
              context.push('/conversation/$chatId');
            },
          );
        },
      ),
    );
  }
}

/// Shows the list of existing DM chats from ChatProvider
class _ExistingChats extends StatelessWidget {
  final VoidCallback onClose;
  const _ExistingChats({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final chats = chatProvider.chats
        .where((c) =>
            !c.chatId.startsWith('ai_') &&
            c.participants.contains(auth.uid))
        .toList();

    if (chats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('No conversations yet.\nSearch for users to start chatting!',
            style: TextStyle(color: kMutedFg, fontSize: 13)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Recent Chats',
              style: TextStyle(
                  color: kMutedFg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        ...chats.map((chat) {
          final otherUid = chat.participants
              .firstWhere((p) => p != auth.uid, orElse: () => '');
          return _ExistingChatTile(
            chatId: chat.chatId,
            otherUid: otherUid,
            onClose: onClose,
          );
        }),
      ],
    );
  }
}

class _ExistingChatTile extends StatefulWidget {
  final String chatId;
  final String otherUid;
  final VoidCallback onClose;
  const _ExistingChatTile(
      {required this.chatId,
      required this.otherUid,
      required this.onClose});

  @override
  State<_ExistingChatTile> createState() => _ExistingChatTileState();
}

class _ExistingChatTileState extends State<_ExistingChatTile> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await UserRepo().getUser(widget.otherUid);
    if (mounted) setState(() => _user = u);
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.username ?? widget.otherUid;
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: kOrange,
            backgroundImage: (_user?.avatarUrl.isNotEmpty == true)
                ? CachedNetworkImageProvider(_user!.avatarUrl)
                : null,
            child: (_user?.avatarUrl.isEmpty != false)
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 14))
                : null,
          ),
        ],
      ),
      title: Text(name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      onTap: () {
        widget.onClose();
        context.push('/conversation/${widget.chatId}');
      },
    );
  }
}
