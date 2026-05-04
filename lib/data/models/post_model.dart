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
  final String location;
  final double lat;
  final double lng;
  final String category;
  final int upvotes;
  final int downvotes;
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
    this.location = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.category = 'Restaurant',
    this.upvotes = 0,
    this.downvotes = 0,
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
      location: map['location'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'Restaurant',
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
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
      'location': location,
      'lat': lat,
      'lng': lng,
      'category': category,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'commentCount': commentCount,
      'createdAt': createdAt,
    };
  }

  PostModel copyWith({
    int? upvotes,
    int? downvotes,
    int? commentCount,
    String? imageUrl,
  }) {
    return PostModel(
      postId: postId,
      userId: userId,
      username: username,
      userAvatarUrl: userAvatarUrl,
      isSuperUser: isSuperUser,
      title: title,
      description: description,
      localTips: localTips,
      recommendedDishes: recommendedDishes,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location,
      lat: lat,
      lng: lng,
      category: category,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
    );
  }
}
