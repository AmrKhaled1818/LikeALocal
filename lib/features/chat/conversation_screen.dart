import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/message_model.dart';
import '../../data/models/post_model.dart';
import '../../data/services/ai_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/chat_provider.dart';
import '../../shared/providers/posts_provider.dart';

class ConversationScreen extends StatefulWidget {
  final String chatId;
  const ConversationScreen({super.key, required this.chatId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  Position? _position;

  bool get _isAiChat => widget.chatId.startsWith('ai_');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<ChatProvider>().markRead(widget.chatId, auth.uid);
    });
    if (_isAiChat) _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      if (mounted) setState(() => _position = pos);
    } catch (_) {}
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('All messages with the AI assistant will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ChatProvider>().clearChat(widget.chatId);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final auth = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    _msgCtrl.clear();
    setState(() => _sending = true);

    try {
      final userMsg = MessageModel(
        msgId: '',
        senderId: auth.uid,
        text: text,
        createdAt: Timestamp.now(),
      );
      await chatProvider.sendMessage(widget.chatId, userMsg, auth.uid);
      _scrollToBottom();

      if (_isAiChat && auth.userModel != null) {
        final messages = await chatProvider.getMessages(widget.chatId).first;
        final reply = await AIService().getAIResponse(
          messages,
          auth.userModel!,
          lat: _position?.latitude,
          lng: _position?.longitude,
        );

        final aiMsg = MessageModel(
          msgId: '',
          senderId: 'ai',
          text: reply,
          type: 'ai_response',
          createdAt: Timestamp.now(),
        );
        await chatProvider.sendMessage(widget.chatId, aiMsg, 'ai');
        _scrollToBottom();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<PostModel> _findRelatedPosts(String aiText, List<PostModel> allPosts) {
    final lower = aiText.toLowerCase();
    final scored = <PostModel, int>{};
    for (final post in allPosts) {
      int score = 0;
      final titleWords = post.title
          .toLowerCase()
          .split(RegExp(r'\W+'))
          .where((w) => w.length > 3);
      final locationWords = post.location
          .toLowerCase()
          .split(RegExp(r'\W+'))
          .where((w) => w.length > 3);
      for (final word in [...titleWords, ...locationWords]) {
        if (lower.contains(word)) score++;
      }
      if (post.category.isNotEmpty &&
          lower.contains(post.category.toLowerCase())) score += 2;
      if (score > 0) scored[post] = score;
    }
    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allPosts = context.watch<PostsProvider>().feedPosts;

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: _isAiChat
            ? const _AiAppBarTitle()
            : Text(
                widget.chatId,
                style:
                    const TextStyle(color: Colors.white, fontSize: 16),
              ),
        actions: [
          if (_isAiChat)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              tooltip: 'Clear chat',
              onPressed: _confirmClearChat,
            ),
          if (!_isAiChat)
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () {},
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isAiChat) const _AiWelcomeBanner(),
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream:
                  context.read<ChatProvider>().getMessages(widget.chatId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: kOrange));
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      _isAiChat
                          ? 'Ask me about local spots, hidden gems, or travel tips!'
                          : 'No messages yet. Say hello!',
                      style: const TextStyle(color: kMutedFg),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == auth.uid;
                    final isAi = msg.senderId == 'ai';
                    final related = (isAi && _isAiChat)
                        ? _findRelatedPosts(msg.text, allPosts)
                        : <PostModel>[];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MessageBubble(
                            message: msg, isMe: isMe, isAi: isAi),
                        if (related.isNotEmpty)
                          _RelatedPostsRow(posts: related),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: _isAiChat
                      ? 'Ask the AI assistant...'
                      : 'Type a message...',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            _sending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: kOrange, strokeWidth: 2),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: kOrange, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RelatedPostsRow extends StatelessWidget {
  final List<PostModel> posts;
  const _RelatedPostsRow({required this.posts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Related spots in app:',
            style: TextStyle(
                fontSize: 11,
                color: kMutedFg,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _PostChip(post: posts[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostChip extends StatelessWidget {
  final PostModel post;
  const _PostChip({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.postId}'),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: post.isSuperUser ? kAmber : kOrange, width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place,
                    size: 12,
                    color: post.isSuperUser ? kAmber : kOrange),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: kDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              post.location,
              style:
                  const TextStyle(fontSize: 10, color: kMutedFg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/post/${post.postId}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            (post.isSuperUser ? kAmber : kOrange)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text('View Post',
                            style: TextStyle(
                                fontSize: 10,
                                color: kOrange,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => context.go('/map'),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: kOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.map_outlined,
                        size: 14, color: kOrange),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiAppBarTitle extends StatelessWidget {
  const _AiAppBarTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 8),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI Discovery Assistant',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            Text('Powered by Gemini',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class _AiWelcomeBanner extends StatelessWidget {
  const _AiWelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E8FF), Color(0xFFFCE7F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFF8B5CF6), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'I can help you discover hidden gems, find local spots, and plan your adventure!',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6D28D9),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isAi;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isAi,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            isAi
                ? Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 14),
                  )
                : CircleAvatar(
                    radius: 14,
                    backgroundColor: kOrange,
                    child: Text(
                      message.senderId.isNotEmpty
                          ? message.senderId[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? kOrange
                    : isAi
                        ? const Color(0xFFF3E8FF)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isMe
                      ? Colors.white
                      : isAi
                          ? const Color(0xFF6D28D9)
                          : kDark,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
