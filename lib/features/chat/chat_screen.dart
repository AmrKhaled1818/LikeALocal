import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repo.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../data/models/message_model.dart';
import 'friends_sidebar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _sidebarOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.uid.isNotEmpty) {
        context.read<ChatProvider>().startListening(auth.uid);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return Stack(
      children: [
        Scaffold(
          body: ResponsiveBody(
            maxWidth: AppBreakpoints.maxFeedWidth,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  Expanded(child: _buildChatList()),
                ],
              ),
            ),
          ),
        ),
        if (_sidebarOpen)
          FriendsSidebar(
            isOpen: _sidebarOpen,
            onClose: () => setState(() => _sidebarOpen = false),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Text(
            'Messages',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: null),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.people_outline, color: null),
            onPressed: () => setState(() => _sidebarOpen = true),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search, color: kMutedFg, size: 20),
          hintText: 'Search conversations...',
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final chats = chatProvider.chats;

    final dmChats = chats.where((c) => !c.chatId.startsWith('ai_')).toList();
    final filtered = _query.isEmpty
        ? dmChats
        : dmChats
            .where((c) =>
                c.chatId.toLowerCase().contains(_query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return ListView(
      children: [
        // AI Discovery Assistant — always first
        _AiChatTile(uid: auth.uid),
        if (filtered.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Direct Messages',
              style: const TextStyle(
                  color: kMutedFg, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          ...filtered.map((chat) => _ChatTile(
                chat: chat,
                currentUid: auth.uid,
              )),
        ],
        if (filtered.isEmpty && _query.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No conversations found',
                  style: TextStyle(color: kMutedFg)),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _AiChatTile extends StatelessWidget {
  final String uid;
  const _AiChatTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        final chatProvider = context.read<ChatProvider>();
        final chatId = await chatProvider.getOrCreateAiChat(uid);
        if (!context.mounted) return;
        if (chatId == null) {
          AppToast.error('Could not open AI chat. Check your connection.');
          return;
        }
        context.push('/conversation/$chatId');
      },
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
      ),
      title: const Text(
        'AI Discovery Assistant',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: const Text(
        'Ask me anything about local spots!',
        style: TextStyle(color: kMutedFg, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'AI',
          style: TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final ChatModel chat;
  final String currentUid;

  const _ChatTile({required this.chat, required this.currentUid});

  String get _otherUid =>
      chat.participants.firstWhere((p) => p != currentUid, orElse: () => '');

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = widget._otherUid;
    if (uid.isEmpty) return;
    final user = await UserRepo().getUser(uid);
    if (mounted) setState(() => _otherUser = user);
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.chat.unreadCount[widget.currentUid] ?? 0;
    final timeStr = _formatTime(widget.chat.lastMessageAt.toDate());
    final displayName = _otherUser?.username ?? widget._otherUid;
    final avatarUrl = _otherUser?.avatarUrl ?? '';

    return ListTile(
      onTap: () => context.push('/conversation/${widget.chat.chatId}'),
      leading: CircleAvatar(
        backgroundColor: kOrange,
        backgroundImage:
            avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        widget.chat.lastMessage.isEmpty ? 'No messages yet' : widget.chat.lastMessage,
        style: const TextStyle(color: kMutedFg, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(timeStr,
              style: const TextStyle(color: kMutedFg, fontSize: 11)),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }
}
