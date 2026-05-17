import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/map_utils.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/models/message_model.dart';
import '../../data/models/post_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/chat_repo.dart';
import '../../data/repositories/user_repo.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/cloudinary_service.dart';
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
  bool _sendingImage = false;
  Position? _position;
  String? _otherUsername;
  String? _otherUid;

  // Typing-indicator state
  late final ChatProvider _chatRef;
  late final String _uid;
  late final Stream<bool> _typingStream;
  Timer? _typingTimer;
  bool _amTyping = false;

  int _todayAiCount = 0;
  bool _limitLoaded = false;

  // Track message count to only auto-scroll on new messages, not every rebuild
  int _lastMsgCount = 0;
  // Latest messages snapshot — avoids redundant Firestore fetch when sending AI message
  List<MessageModel> _currentMessages = [];

  static const _dailyLimit = 20;
  static const _genericQueryWords = <String>{
    // articles / prepositions
    'a', 'an', 'the', 'in', 'at', 'on', 'for', 'to', 'of', 'and', 'or',
    'with', 'near', 'around', 'from', 'by', 'up', 'its',
    // pronouns / helpers
    'me', 'my', 'i', 'you', 'can', 'could', 'please', 'want', 'need',
    'get', 'find', 'show', 'give', 'tell', 'like', 'know', 'have', 'has',
    // greetings / filler
    'hello', 'hi', 'hey', 'thanks', 'thank', 'okay', 'ok', 'yes', 'no',
    'sure', 'great', 'good', 'nice', 'cool', 'awesome', 'wow', 'help',
    // vague place words (too broad to score)
    'suggest', 'recommend', 'place', 'places', 'spot', 'spots',
    'local', 'best', 'any', 'some', 'here', 'there', 'area', 'city',
  };

  // Accent-fold + lowercase so "Café" matches "cafe", "résidence" matches "residence", etc.
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e').replaceAll('ë', 'e')
      .replaceAll('à', 'a').replaceAll('â', 'a').replaceAll('ä', 'a')
      .replaceAll('ô', 'o').replaceAll('ö', 'o')
      .replaceAll('ü', 'u').replaceAll('û', 'u')
      .replaceAll('ç', 'c').replaceAll('ñ', 'n')
      .replaceAll("'", '').replaceAll('-', ' ');

  bool get _isAiChat => widget.chatId.startsWith('ai_');
  bool get _limitReached => _limitLoaded && _todayAiCount >= _dailyLimit;

  @override
  void initState() {
    super.initState();
    _chatRef = context.read<ChatProvider>();
    _uid = context.read<AuthProvider>().uid;
    _typingStream = _chatRef.watchTyping(widget.chatId, _uid);
    _chatRef.setCurrentChat(widget.chatId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatRef.markRead(widget.chatId, _uid);
      if (!_isAiChat) _loadOtherUsername(_uid);
      if (_isAiChat) _loadAiUsage(_uid);
    });
    if (_isAiChat) _fetchLocation();
  }

  void _onTextChanged(String text) {
    if (_isAiChat || _uid.isEmpty) return;
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_amTyping) {
      _amTyping = true;
      _chatRef.setTyping(widget.chatId, _uid, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    _typingTimer = null;
    if (_amTyping) {
      _amTyping = false;
      if (_uid.isNotEmpty) _chatRef.setTyping(widget.chatId, _uid, false);
    }
  }

  Future<void> _loadAiUsage(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final countKey = 'ai_count_$uid';
    final resetKey = 'ai_reset_$uid';
    final resetMs = prefs.getInt(resetKey);
    final now = DateTime.now();
    if (resetMs != null) {
      final resetTime = DateTime.fromMillisecondsSinceEpoch(resetMs);
      if (now.difference(resetTime).inHours >= 24) {
        await prefs.setInt(countKey, 0);
        await prefs.setInt(resetKey, now.millisecondsSinceEpoch);
      }
    } else {
      await prefs.setInt(resetKey, now.millisecondsSinceEpoch);
    }
    if (mounted) {
      setState(() {
        _todayAiCount = prefs.getInt(countKey) ?? 0;
        _limitLoaded = true;
      });
    }
  }

  Future<void> _incrementAiCount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final countKey = 'ai_count_$uid';
    final newCount = (_todayAiCount + 1);
    await prefs.setInt(countKey, newCount);
    if (mounted) setState(() => _todayAiCount = newCount);
  }

  Future<void> _loadOtherUsername(String myUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (!doc.exists) return;
      final participants =
          List<String>.from(doc.data()!['participants'] ?? []);
      final otherUid =
          participants.firstWhere((p) => p != myUid, orElse: () => '');
      if (otherUid.isEmpty) return;
      final user = await UserRepo().getUser(otherUid);
      if (mounted && user != null) {
        setState(() {
          _otherUsername = user.username;
          _otherUid = otherUid;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendImageMessage() async {
    if (_sendingImage) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;

    final chatProvider = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();

    setState(() => _sendingImage = true);
    try {
      final result = await CloudinaryService().uploadImage(file);
      if (!mounted) return;
      final msg = MessageModel(
        msgId: '',
        senderId: auth.uid,
        text: '',
        type: 'image',
        imageUrl: result.imageUrl,
        createdAt: Timestamp.now(),
      );
      await chatProvider.sendMessage(widget.chatId, msg, auth.uid);
      _scrollToBottom();
    } catch (_) {
      if (mounted) AppToast.error('Failed to send image. Try again.');
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete message',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await ChatRepo().deleteMessage(widget.chatId, msg.msgId);
      } catch (_) {
        if (mounted) AppToast.error('Failed to delete message.');
      }
    }
  }

  String _formatLastSeen(Timestamp? ts) {
    if (ts == null) return 'Offline';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }

  Future<void> _fetchLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      if (mounted) setState(() => _position = pos);
    } catch (_) {}
  }

  @override
  void dispose() {
    _chatRef.setCurrentChat(null);
    _stopTyping();
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
      try {
        await context.read<ChatProvider>().clearChat(widget.chatId);
        AppToast.success('Chat cleared.');
      } catch (_) {
        AppToast.error('Failed to clear chat. Try again.');
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final auth = context.read<AuthProvider>();
    final isSuperUser = auth.userModel?.isSuperUser ?? false;
    final isPremium = auth.userModel?.isPremium ?? false;

    if (_isAiChat && !isSuperUser && !isPremium && _limitReached) return;

    final chatProvider = context.read<ChatProvider>();
    final postsProvider = context.read<PostsProvider>();
    _msgCtrl.clear();
    _stopTyping();
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
        // Use the already-loaded message list — no redundant Firestore fetch
        final messages = _currentMessages;
        final allPosts = postsProvider.allPosts;
        final availablePlaces = allPosts.map((p) => '${p.title} in ${p.location}').join(', ');

        final reply = await AIService().getAIResponse(
          messages,
          auth.userModel!,
          lat: _position?.latitude,
          lng: _position?.longitude,
          availablePlaces: availablePlaces,
        );

        final aiMsg = MessageModel(
          msgId: '',
          senderId: 'ai',
          text: reply,
          type: 'ai_response',
          createdAt: Timestamp.now(),
        );
        await chatProvider.sendMessage(widget.chatId, aiMsg, 'ai');
        if (!isSuperUser && !isPremium) await _incrementAiCount(auth.uid);
        _scrollToBottom();
      }
    } catch (e) {
      AppToast.error('Failed to send message. Try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<PostModel> _findRelatedPosts(
      String aiText, String userQuery, List<PostModel> allPosts) {
    final queryNorm = _norm(userQuery);
    final aiNorm = _norm(aiText);

    final queryTokens = queryNorm
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 2 && !_genericQueryWords.contains(w))
        .toSet();

    if (queryTokens.isEmpty) return [];

    // Find which query tokens are location words by checking against post location fields.
    // When the user names a location ("zamalek", "maadi"), only posts there qualify.
    final knownLocationWords = <String>{};
    for (final post in allPosts) {
      _norm(post.location)
          .split(RegExp(r'\W+'))
          .where((w) => w.length > 2)
          .forEach(knownLocationWords.add);
    }
    final queryLocationTokens = queryTokens.intersection(knownLocationWords);

    final scored = <PostModel, int>{};

    for (final post in allPosts) {
      int score = 0;
      final titleNorm = _norm(post.title);
      final locationNorm = _norm(post.location);
      final descNorm = _norm(post.description);
      final catNorm = _norm(post.category);

      // 1. AI explicitly named this place — highest signal.
      //    Match any meaningful title word found in the AI response text.
      for (final tw in titleNorm
          .split(RegExp(r'\W+'))
          .where((w) => w.length > 2 && !_genericQueryWords.contains(w))) {
        if (aiNorm.contains(tw)) { score += 12; break; }
      }

      // 2. User query tokens — normalized so "cafe" matches "café" category.
      for (final token in queryTokens) {
        if (titleNorm.contains(token)) { score += 8; }
        else if (locationNorm.contains(token)) { score += 5; }
        else if (catNorm.contains(token)) { score += 4; }
        else if (descNorm.contains(token)) { score += 1; }
      }

      // 3. Distance bonus.
      if (_position != null && (post.lat != 0 || post.lng != 0)) {
        final dist = Geolocator.distanceBetween(
          _position!.latitude, _position!.longitude,
          post.lat, post.lng,
        );
        if (dist < 3000) { score += 5; }
        else if (dist < 8000) { score += 2; }
      }

      // 4. Location gate: if the user named a specific area, skip posts outside it.
      if (queryLocationTokens.isNotEmpty) {
        final inArea = queryLocationTokens.any(
          (lw) => locationNorm.contains(lw) || titleNorm.contains(lw),
        );
        if (!inArea) continue;
      }

      if (score >= 6) scored[post] = score;
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(3).map((e) => e.key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allPosts = context.watch<PostsProvider>().allPosts;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: _isAiChat
            ? const _AiAppBarTitle()
            : _otherUid == null
                ? Text(_otherUsername ?? 'Chat',
                    style: const TextStyle(color: Colors.white, fontSize: 16))
                : StreamBuilder<UserModel?>(
                    stream: UserRepo().watchUser(_otherUid!),
                    builder: (_, snap) {
                      final other = snap.data;
                      final statusText = other == null
                          ? ''
                          : other.isReallyOnline
                              ? 'Online'
                              : _formatLastSeen(other.lastSeen);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _otherUsername ?? 'Chat',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          if (statusText.isNotEmpty)
                            Text(
                              statusText,
                              style: TextStyle(
                                color: other?.isReallyOnline == true
                                    ? const Color(0xFF4ADE80)
                                    : Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
        actions: [
          if (_isAiChat)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              tooltip: 'Clear chat',
              onPressed: _confirmClearChat,
            ),
        ],
      ),
      body: StreamBuilder<List<MessageModel>>(
        stream: context.read<ChatProvider>().getMessages(widget.chatId),
        builder: (context, snap) {
          final messages = snap.data ?? [];
          final isSuperUser = auth.userModel?.isSuperUser ?? false;
          final isPremium = auth.userModel?.isPremium ?? false;
          final limitReached = _isAiChat && !isSuperUser && !isPremium && _limitReached;
          final todayAiMsgs = _todayAiCount;

          // Keep current messages available for AI sending (avoids redundant fetch)
          _currentMessages = messages;

          // When new messages arrive: scroll to bottom AND mark as read immediately.
          // This keeps the unread badge at 0 and flips read receipts to blue ticks
          // without requiring the user to leave and re-enter the chat.
          if (messages.length > _lastMsgCount) {
            _lastMsgCount = messages.length;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _chatRef.markRead(widget.chatId, _uid);
              if (_scrollCtrl.hasClients) {
                _scrollCtrl.animateTo(
                  _scrollCtrl.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }

          Widget listWidget;
          if (snap.connectionState == ConnectionState.waiting && messages.isEmpty) {
            listWidget = const Center(
                child: CircularProgressIndicator(color: kOrange));
          } else if (messages.isEmpty) {
            listWidget = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isAiChat) ...[
                  const _AiWelcomeBanner(),
                  const SizedBox(height: 16),
                ],
                Text(
                  _isAiChat
                      ? 'Ask me about local spots, hidden gems, or travel tips!'
                      : 'No messages yet. Say hello!',
                  style: const TextStyle(color: kMutedFg),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          } else {
            listWidget = ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: messages.length + (_isAiChat ? 1 : 0),
              itemBuilder: (_, i) {
                if (_isAiChat && i == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: _AiWelcomeBanner(),
                  );
                }
                final idx = _isAiChat ? i - 1 : i;
                final msg = messages[idx];
                final isMe = msg.senderId == auth.uid;
                final isAi = msg.senderId == 'ai';
                // Pass the preceding user message as the query for better matching
                final userQuery = (isAi && idx > 0 && messages[idx - 1].senderId != 'ai')
                    ? messages[idx - 1].text
                    : '';
                final related = (isAi && _isAiChat)
                    ? _findRelatedPosts(msg.text, userQuery, allPosts)
                    : <PostModel>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      isAi: isAi,
                      myUid: auth.uid,
                      onDelete: (isMe && !_isAiChat)
                          ? () => _deleteMessage(msg)
                          : null,
                    ),
                    if (related.isNotEmpty)
                      _RelatedPostsRow(posts: related),
                  ],
                );
              },
            );
          }

          final lastWasRecommendation = messages.isNotEmpty &&
              messages.any((m) => m.senderId == 'ai') &&
              messages.lastWhere((m) => m.senderId == 'ai').text.contains('**');

          return ResponsiveBody(
            maxWidth: AppBreakpoints.maxDetailWidth,
            child: Column(
              children: [
                Expanded(child: listWidget),
                if (_isAiChat && _sending)
                  const _TypingBubble(label: 'AI is thinking', isAi: true)
                else if (!_isAiChat)
                  StreamBuilder<bool>(
                    stream: _typingStream,
                    builder: (_, s) => (s.data ?? false)
                        ? _TypingBubble(
                            label:
                                '${_otherUsername ?? 'They'} is typing',
                            isAi: false)
                        : const SizedBox.shrink(),
                  ),
                if (_isAiChat && !limitReached && lastWasRecommendation)
                  _buildSuggestionChips(),
                _buildInputBar(limitReached, todayAiMsgs),
              ],
            ),
          );
        },
      ),
    );
  }

  // F36 — Quick-reply chips
  static const _quickReplies = [
    'Tell me more',
    'Any alternatives?',
    'How to get there?',
    'What are the prices?',
    'Best time to visit?',
  ];

  Widget _buildSuggestionChips() {
    return Container(
      height: 46,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            _msgCtrl.text = _quickReplies[i];
            _msgCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _msgCtrl.text.length));
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
            ),
            child: Text(
              _quickReplies[i],
              style: const TextStyle(
                  color: Color(0xFF6D28D9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool limitReached, int todayAiMsgs) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isAiChat && !limitReached) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: todayAiMsgs / _dailyLimit,
                        minHeight: 3,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          todayAiMsgs >= 16 ? kOrange : const Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_dailyLimit - todayAiMsgs).clamp(0, _dailyLimit)}/$_dailyLimit',
                    style: TextStyle(
                      color: todayAiMsgs >= 16 ? kOrange : kMutedFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (limitReached)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  color: kDestructive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kDestructive.withValues(alpha: 0.25)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, color: kDestructive, size: 22),
                    const SizedBox(height: 6),
                    const Text(
                      'Daily limit reached (20/20)',
                      style: TextStyle(
                          color: kDestructive,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Resets tomorrow · Earn 100 karma for unlimited',
                      style: TextStyle(color: kMutedFg, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!_isAiChat)
                    _sendingImage
                        ? const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: kOrange, strokeWidth: 2),
                                ),
                              ),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.image_outlined,
                                color: kMutedFg),
                            tooltip: 'Send image',
                            onPressed: _sendImageMessage,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
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
                        onChanged: _onTextChanged,
                        onSubmitted: (_) => _sendMessage(),
                      ),
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
          color: Theme.of(context).colorScheme.surface,
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
                        color: null),
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
                        color: (post.isSuperUser ? kAmber : kOrange)
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
                  onTap: () => launchDirections(context, post),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: kOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.directions, size: 14, color: kOrange),
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
            Text('Powered by AI',
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

/// Animated "… is typing" bubble shown at the bottom of the conversation.
class _TypingBubble extends StatefulWidget {
  final String label;
  final bool isAi;
  const _TypingBubble({required this.label, required this.isAi});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isAi ? const Color(0xFF8B5CF6) : kOrange;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isAi
                ? const Color(0xFFF3E8FF)
                : Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
                      final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: accent, shape: BoxShape.circle),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isAi;
  final String myUid;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isAi,
    required this.myUid,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // F32 — Read receipt: has anyone else read this message?
    final isRead = isMe &&
        message.readBy.any((uid) => uid != myUid);

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
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: onDelete,
                  child: message.type == 'image' && message.imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl,
                            width: 220,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 220,
                              height: 160,
                              color: kMuted,
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      color: kOrange, strokeWidth: 2)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 220,
                              height: 120,
                              color: kMuted,
                              child: const Icon(Icons.broken_image,
                                  color: kMutedFg),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
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
                          child: isAi
                              ? MarkdownBody(
                                  data: message.text,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(
                                        color: Color(0xFF6D28D9),
                                        fontSize: 14,
                                        height: 1.4),
                                    strong: const TextStyle(
                                        color: Color(0xFF6D28D9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                    listBullet: const TextStyle(
                                        color: Color(0xFF6D28D9), fontSize: 14),
                                    h1: const TextStyle(
                                        color: Color(0xFF6D28D9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                    h2: const TextStyle(
                                        color: Color(0xFF6D28D9),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              : Text(
                                  message.text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : kDark,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                ),
                if (isMe && !isAi) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 13,
                        color: isRead ? Colors.blue : kMutedFg,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }
}
