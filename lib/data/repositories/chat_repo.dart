import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'user_repo.dart';

class ChatRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final UserRepo _userRepo = UserRepo();

  Stream<List<ChatModel>> getUserChats(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final chats =
          snap.docs.map((d) => ChatModel.fromMap(d.data(), d.id)).toList();
      chats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return chats;
    });
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<String> getOrCreateChat(
      String currentUserId, String otherUserId) async {
    // Single where clause avoids the composite index requirement;
    // isGroup is filtered client-side.
    final snap = await _db
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['isGroup'] == true) continue;
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(otherUserId) && participants.length == 2) {
        return doc.id;
      }
    }

    final ref = _db.collection('chats').doc();
    final chat = ChatModel(
      chatId: ref.id,
      participants: [currentUserId, otherUserId],
      isGroup: false,
      lastMessage: '',
      lastMessageAt: Timestamp.now(),
      unreadCount: {currentUserId: 0, otherUserId: 0},
    );
    await ref.set(chat.toMap());
    return ref.id;
  }

  Future<void> sendMessage(
      String chatId, MessageModel message, String senderId) async {
    final ref =
        _db.collection('chats').doc(chatId).collection('messages').doc();
    final data = message.toMap();
    data['msgId'] = ref.id;
    await ref.set(data);

    // Fetch sender name once so we can store it on the chat doc AND
    // use it in the notification body. Falls back to 'Someone' on failure.
    String senderName = '';
    if (senderId.isNotEmpty && senderId != 'ai') {
      try {
        final senderDoc = await _db.collection('users').doc(senderId).get();
        senderName = (senderDoc.data()?['username'] as String?) ?? '';
      } catch (_) {}
    }
    if (senderName.isEmpty) senderName = senderId == 'ai' ? 'AI' : 'Someone';

    final chatDoc = await _db.collection('chats').doc(chatId).get();
    String recipientId = '';
    if (chatDoc.exists) {
      final participants =
          List<String>.from(chatDoc.data()!['participants'] ?? []);
      recipientId =
          participants.firstWhere((p) => p != senderId, orElse: () => '');
      final lastMsg = message.type == 'image'
          ? '📷 Photo'
          : message.type == 'video'
              ? '🎥 Video'
              : message.text;
      Map<String, dynamic> update = {
        'lastMessage': lastMsg,
        'lastMessageAt': Timestamp.now(),
        'lastSenderName': senderName,
        'lastSenderId': senderId,
      };
      if (recipientId.isNotEmpty) {
        update['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
      await _db.collection('chats').doc(chatId).update(update);
    }

    // Write a notification doc — body is intentionally generic
    // ("X sent you a message") to keep message contents private.
    if (!chatId.startsWith('ai_') &&
        recipientId.isNotEmpty &&
        senderId != 'ai') {
      try {
        final body = message.type == 'image'
            ? '$senderName sent you a photo'
            : message.type == 'video'
                ? '$senderName sent you a video'
                : '$senderName sent you a message';
        final notifRef = _db.collection('notifications').doc();
        await notifRef.set({
          'notifId': notifRef.id,
          'userId': recipientId,
          'type': 'message',
          'title': 'New message',
          'body': body,
          'postId': null,
          'chatId': chatId,
          'read': false,
          'createdAt': Timestamp.now(),
        });
      } catch (_) {}
    }

    if (senderId != 'ai') await _userRepo.addKarma(senderId, 3);
  }

  Future<void> deleteMessage(String chatId, String msgId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(msgId)
        .delete();
  }

  Future<void> clearChat(String chatId) async {
    final msgs = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.update(_db.collection('chats').doc(chatId),
        {'lastMessage': '', 'lastMessageAt': Timestamp.now()});
    await batch.commit();
  }

  // ── Typing indicators ──────────────────────────────────────────────────────
  // Stored on the chat doc as `typing.{uid}` → server-ish Timestamp (or removed).
  static const _typingStaleSeconds = 6;

  Future<void> setTyping(String chatId, String userId, bool typing) async {
    // AI chats: the AI never types, so skip the write entirely.
    if (chatId.startsWith('ai_')) return;
    await _db.collection('chats').doc(chatId).update({
      'typing.$userId': typing ? Timestamp.now() : FieldValue.delete(),
    });
  }

  /// Emits true while *another* participant has a fresh typing timestamp.
  Stream<bool> watchTyping(String chatId, String myUid) {
    if (chatId.startsWith('ai_')) return Stream.value(false);
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final typing = (doc.data()?['typing'] as Map?) ?? const {};
      final now = DateTime.now();
      for (final entry in typing.entries) {
        if (entry.key == myUid) continue;
        final ts = entry.value;
        if (ts is Timestamp &&
            now.difference(ts.toDate()).inSeconds < _typingStaleSeconds) {
          return true;
        }
      }
      return false;
    });
  }

  Future<void> markRead(String chatId, String userId) async {
    try {
      // Reset unread counter
      await _db
          .collection('chats')
          .doc(chatId)
          .update({'unreadCount.$userId': 0});

      // Mark all messages NOT sent by this user as read by this user
      final snap = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .get();

      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('ChatRepo.markRead error: $e');
    }
  }

  String aiChatId(String userId) => 'ai_$userId';

  Future<String> getOrCreateAiChat(String userId) async {
    final chatId = aiChatId(userId);
    // merge:true → creates the document if it doesn't exist yet,
    // or leaves existing message/lastMessage data untouched if it does.
    // This avoids a GET on a possibly non-existent doc, which Firestore
    // rules deny when resource.data is null.
    await _db.collection('chats').doc(chatId).set(
      {
        'chatId': chatId,
        'participants': [userId, 'ai'],
        'isGroup': false,
      },
      SetOptions(merge: true),
    );
    return chatId;
  }
}
