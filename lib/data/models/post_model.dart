import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String username;
  final String userAvatarUrl;
  final bool isSuperUser;
  final String title;
  final String description;
  final String localTips;
  final List<String> recommendedDishes;
  final String imageUrl;
  final String imagePublicId;
  final String location;
  final double lat;
  final double lng;
  final String category;
  final int upvotes;
  final int downvotes;
  final List<String> upvotedBy;
  final int commentCount;
  final Timestamp createdAt;

  PostModel({
    required this.postId,
    required this.userId,
    required this.username,
    this.userAvatarUrl = '',
    this.isSuperUser = false,
    required this.title,
    this.description = '',
    this.localTips = '',
    this.recommendedDishes = const [],
    this.imageUrl = '',
    this.imagePublicId = '',
    this.location = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.category = 'Restaurant',
    this.upvotes = 0,
    this.downvotes = 0,
    this.upvotedBy = const [],
    this.commentCount = 0,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      postId: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userAvatarUrl: map['userAvatarUrl'] ?? '',
      isSuperUser: map['isSuperUser'] ?? false,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      localTips: map['localTips'] ?? '',
      recommendedDishes:
          List<String>.from(map['recommendedDishes'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      imagePublicId: map['imagePublicId'] ?? '',
      location: map['location'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'Restaurant',
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      upvotedBy: List<String>.from(map['upvotedBy'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userAvatarUrl': userAvatarUrl,
      'isSuperUser': isSuperUser,
      'title': title,
      'description': description,
      'localTips': localTips,
      'recommendedDishes': recommendedDishes,
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
      'location': location,
      'lat': lat,
      'lng': lng,
      'category': category,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'upvotedBy': upvotedBy,
      'commentCount': commentCount,
      'createdAt': createdAt,
    };
  }

  PostModel copyWith({
    String? postId,
    String? userId,
    String? username,
    String? userAvatarUrl,
    bool? isSuperUser,
    String? title,
    String? description,
    String? localTips,
    List<String>? recommendedDishes,
    String? imageUrl,
    String? imagePublicId,
    String? location,
    double? lat,
    double? lng,
    String? category,
    int? upvotes,
    int? downvotes,
    List<String>? upvotedBy,
    int? commentCount,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      isSuperUser: isSuperUser ?? this.isSuperUser,
      title: title ?? this.title,
      description: description ?? this.description,
      localTips: localTips ?? this.localTips,
      recommendedDishes: recommendedDishes ?? this.recommendedDishes,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePublicId: imagePublicId ?? this.imagePublicId,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      category: category ?? this.category,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      upvotedBy: upvotedBy ?? this.upvotedBy,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }
}
