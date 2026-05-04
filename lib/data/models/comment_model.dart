import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool isSuperUser;
  final String content;
  final int upvotes;
  final String? parentId;
  final Timestamp createdAt;
  final Timestamp? editedAt;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.username,
    this.userAvatarUrl = '',
    this.isSuperUser = false,
    required this.content,
    this.upvotes = 0,
    this.parentId,
    Timestamp? createdAt,
    this.editedAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    return CommentModel(
      commentId: id,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userAvatarUrl: map['userAvatarUrl'] ?? '',
      isSuperUser: map['isSuperUser'] ?? false,
      content: map['content'] ?? '',
      upvotes: map['upvotes'] ?? 0,
      parentId: map['parentId'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      editedAt: map['editedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'isSuperUser': isSuperUser,
      'content': content,
      'upvotes': upvotes,
      'parentId': parentId,
      'createdAt': createdAt,
      'editedAt': editedAt,
    };
  }
}
