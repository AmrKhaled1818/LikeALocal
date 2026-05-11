import 'package:cloud_firestore/cloud_firestore.dart';
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

    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final participants =
          List<String>.from(chatDoc.data()!['participants'] ?? []);
      final recipientId =
          participants.firstWhere((p) => p != senderId, orElse: () => '');
      Map<String, dynamic> update = {
        'lastMessage': message.text,
        'lastMessageAt': Timestamp.now(),
      };
      if (recipientId.isNotEmpty) {
        update['unreadCount.$recipientId'] = FieldValue.increment(1);
      }
      await _db.collection('chats').doc(chatId).update(update);
    }

    await _userRepo.addKarma(senderId, 3);
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

  Future<void> markRead(String chatId, String userId) async {
    // Reset unread counter
    await _db
        .collection('chats')
        .doc(chatId)
        .update({'unreadCount.$userId': 0});

    // F32 — Mark all messages NOT sent by this user as read by this user
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
