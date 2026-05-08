import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repo.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepo _repo = ChatRepo();

  List<ChatModel> _chats = [];
  bool _isLoading = false;
  String? _listeningUid;
  StreamSubscription? _chatsSub;

  List<ChatModel> get chats => _chats;
  bool get isLoading => _isLoading;

  void startListening(String userId) {
    // Don't create a duplicate subscription for the same user
    if (_listeningUid == userId) return;
    _chatsSub?.cancel();
    _listeningUid = userId;
    _chatsSub = _repo.getUserChats(userId).listen(
      (chats) {
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
