import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repo.dart';
import '../../data/services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepo _repo = ChatRepo();

  List<ChatModel> _chats = [];
  final bool _isLoading = false;
  String? _listeningUid;
  StreamSubscription? _chatsSub;
  Map<String, int> _prevUnread = {};
  bool _chatsInitialized = false;
  String? _currentOpenChatId;

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isLoading;

  /// Call from ConversationScreen.initState / dispose to suppress notifications
  /// for the chat the user is currently reading.
  void setCurrentChat(String? chatId) {
    _currentOpenChatId = chatId;
  }

  void startListening(String userId) {
    if (_listeningUid == userId) return;
    _chatsSub?.cancel();
    _listeningUid = userId;
    _prevUnread = {};
    _chatsInitialized = false;
    _chatsSub = _repo.getUserChats(userId).listen(
      (chats) {
        if (!_chatsInitialized) {
          // Snapshot existing unread counts without notifying
          _chatsInitialized = true;
          for (final chat in chats) {
            _prevUnread[chat.chatId] = chat.unreadCount[userId] ?? 0;
          }
          _chats = chats;
          notifyListeners();
          return;
        }
        for (final chat in chats) {
          if (chat.chatId.startsWith('ai_')) continue;
          final prev = _prevUnread[chat.chatId] ?? 0;
          final current = chat.unreadCount[userId] ?? 0;
          // Only fire for messages from *other* people — not echoes of our own send.
          final fromMe = chat.lastSenderId == userId;
          if (current > prev &&
              !fromMe &&
              chat.chatId != _currentOpenChatId) {
            final name = chat.lastSenderName.isNotEmpty
                ? chat.lastSenderName
                : 'Someone';
            NotificationService.showLocalNotification(
              'New message',
              '$name sent you a message',
            );
          }
          _prevUnread[chat.chatId] = current;
        }
        _chats = chats;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('ChatProvider error: $e');
      },
    );
  }

  void stopListening() {
    _chatsSub?.cancel();
    _chatsSub = null;
    _listeningUid = null;
    _chats = [];
    notifyListeners();
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _repo.getMessages(chatId);
  }

  Future<String?> getOrCreateChat(
      String currentUserId, String otherUserId) async {
    try {
      return await _repo.getOrCreateChat(currentUserId, otherUserId);
    } catch (e) {
      debugPrint('getOrCreateChat error: $e');
      return null;
    }
  }

  Future<String?> getOrCreateAiChat(String userId) async {
    try {
      return await _repo.getOrCreateAiChat(userId);
    } catch (e) {
      debugPrint('getOrCreateAiChat error: $e');
      return null;
    }
  }

  Future<void> sendMessage(
      String chatId, MessageModel message, String senderId) async {
    try {
      await _repo.sendMessage(chatId, message, senderId);
    } catch (e) {
      debugPrint('sendMessage error: $e');
    }
  }

  Future<void> clearChat(String chatId) async {
    try {
      await _repo.clearChat(chatId);
    } catch (e) {
      debugPrint('clearChat error: $e');
    }
  }

  Future<void> markRead(String chatId, String userId) async {
    try {
      await _repo.markRead(chatId, userId);
    } catch (_) {}
  }

  Future<void> setTyping(String chatId, String userId, bool typing) async {
    try {
      await _repo.setTyping(chatId, userId, typing);
    } catch (_) {}
  }

  Stream<bool> watchTyping(String chatId, String myUid) =>
      _repo.watchTyping(chatId, myUid);

  int getUnreadCount(String userId) {
    int total = 0;
    for (final chat in _chats) {
      total += chat.unreadCount[userId] ?? 0;
    }
    return total;
  }

  @override
  void dispose() {
    _chatsSub?.cancel();
    super.dispose();
  }
}
