import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String msgId;
  final String senderId;
  final String text;
  final String type; // text, image, video, ai_response
  final Timestamp createdAt;
  final List<String> readBy;
  final String imageUrl; // non-empty for type == 'image'
  final String videoUrl; // non-empty for type == 'video'

  MessageModel({
    required this.msgId,
    required this.senderId,
    required this.text,
    this.type = 'text',
    Timestamp? createdAt,
    List<String>? readBy,
    this.imageUrl = '',
    this.videoUrl = '',
  })  : createdAt = createdAt ?? Timestamp.now(),
        readBy = readBy ?? [];

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      msgId: id,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'createdAt': createdAt,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
    };
  }
}

class ChatModel {
  final String chatId;
  final List<String> participants;
  final bool isGroup;
  final String? groupName;
  final String lastMessage;
  final String lastSenderName; // username of whoever sent lastMessage
  final String lastSenderId;
  final Timestamp lastMessageAt;
  final Map<String, int> unreadCount;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.isGroup = false,
    this.groupName,
    this.lastMessage = '',
    this.lastSenderName = '',
    this.lastSenderId = '',
    Timestamp? lastMessageAt,
    Map<String, int>? unreadCount,
  })  : lastMessageAt = lastMessageAt ?? Timestamp.now(),
        unreadCount = unreadCount ?? {};

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      chatId: id,
      participants: List<String>.from(map['participants'] ?? []),
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      lastMessage: map['lastMessage'] ?? '',
      lastSenderName: map['lastSenderName'] ?? '',
      lastSenderId: map['lastSenderId'] ?? '',
      lastMessageAt: map['lastMessageAt'] ?? Timestamp.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'isGroup': isGroup,
      'groupName': groupName,
      'lastMessage': lastMessage,
      'lastSenderName': lastSenderName,
      'lastSenderId': lastSenderId,
      'lastMessageAt': lastMessageAt,
      'unreadCount': unreadCount,
    };
  }
}

class NotificationModel {
  final String notifId;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? postId;
  final String? chatId; // set when type == 'message'
  final bool read;
  final Timestamp createdAt;

  NotificationModel({
    required this.notifId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.postId,
    this.chatId,
    this.read = false,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      notifId: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      postId: map['postId'],
      chatId: map['chatId'],
      read: map['read'] ?? false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'postId': postId,
      'chatId': chatId,
      'read': read,
      'createdAt': createdAt,
    };
  }
}
