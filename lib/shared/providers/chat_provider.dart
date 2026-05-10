import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repo.dart';
import '../../data/services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepo _repo = ChatRepo();

  List<ChatModel> _chats = [];
  bool _isLoading = false;
  String? _listeningUid;
  StreamSubscription? _chatsSub;
  Map<String, int> _prevUnread = {};
  bool _chatsInitialized = false;

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isLoading;

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
          if (current > prev && chat.lastMessage.isNotEmpty) {
            NotificationService.showLocalNotification(
              'New message',
              chat.lastMessage,
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

  Future<String> getOrCreateChat(
      String currentUserId, String otherUserId) async {
    return await _repo.getOrCreateChat(currentUserId, otherUserId);
  }

  Future<String> getOrCreateAiChat(String userId) async {
    return await _repo.getOrCreateAiChat(userId);
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
