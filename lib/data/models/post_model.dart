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
  // Multi-image support. imageUrls is the canonical list.
  // imageUrl/imagePublicId kept for backward compatibility with existing Firestore docs.
  final String imageUrl;
  final String imagePublicId;
  final List<String> imageUrls;
  final List<String> imagePublicIds;
  final String location;
  final double lat;
  final double lng;
  final String category;
  final int upvotes;
  final int downvotes;
  final List<String> upvotedBy;
  final int commentCount;
  final Timestamp createdAt;
  final bool isSponsoredContent;
  final String aiSummary;

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
    this.imageUrls = const [],
    this.imagePublicIds = const [],
    this.location = '',
    this.lat = 0.0,
    this.lng = 0.0,
    this.category = 'Restaurant',
    this.upvotes = 0,
    this.downvotes = 0,
    this.upvotedBy = const [],
    this.commentCount = 0,
    Timestamp? createdAt,
    this.isSponsoredContent = false,
    this.aiSummary = '',
  }) : createdAt = createdAt ?? Timestamp.now();

  /// All image URLs for this post. Falls back to legacy single imageUrl field.
  List<String> get allImageUrls {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return [];
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    final legacyUrl = (map['imageUrl'] as String?) ?? '';
    final legacyPublicId = (map['imagePublicId'] as String?) ?? '';
    final urls = List<String>.from(map['imageUrls'] ?? []);
    final publicIds = List<String>.from(map['imagePublicIds'] ?? []);

    // Migrate legacy single-image doc into the list fields
    if (urls.isEmpty && legacyUrl.isNotEmpty) {
      urls.add(legacyUrl);
      if (legacyPublicId.isNotEmpty) publicIds.add(legacyPublicId);
    }

    return PostModel(
      postId: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userAvatarUrl: map['userAvatarUrl'] ?? '',
      isSuperUser: map['isSuperUser'] ?? false,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      localTips: map['localTips'] ?? '',
      recommendedDishes: List<String>.from(map['recommendedDishes'] ?? []),
      imageUrl: urls.isNotEmpty ? urls.first : legacyUrl,
      imagePublicId: publicIds.isNotEmpty ? publicIds.first : legacyPublicId,
      imageUrls: urls,
      imagePublicIds: publicIds,
      location: map['location'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      category: map['category'] ?? 'Restaurant',
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      upvotedBy: List<String>.from(map['upvotedBy'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      isSponsoredContent: map['isSponsoredContent'] ?? false,
      aiSummary: map['aiSummary'] ?? '',
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
      // Write both formats for backward compat
      'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : imageUrl,
      'imagePublicId': imagePublicIds.isNotEmpty ? imagePublicIds.first : imagePublicId,
      'imageUrls': imageUrls.isNotEmpty ? imageUrls : (imageUrl.isNotEmpty ? [imageUrl] : []),
      'imagePublicIds': imagePublicIds.isNotEmpty ? imagePublicIds : (imagePublicId.isNotEmpty ? [imagePublicId] : []),
      'location': location,
      'lat': lat,
      'lng': lng,
      'category': category,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'upvotedBy': upvotedBy,
      'commentCount': commentCount,
      'createdAt': createdAt,
      'isSponsoredContent': isSponsoredContent,
      'aiSummary': aiSummary,
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
    List<String>? imageUrls,
    List<String>? imagePublicIds,
    String? location,
    double? lat,
    double? lng,
    String? category,
    int? upvotes,
    int? downvotes,
    List<String>? upvotedBy,
    int? commentCount,
    bool? isSponsoredContent,
    String? aiSummary,
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
      imageUrls: imageUrls ?? this.imageUrls,
      imagePublicIds: imagePublicIds ?? this.imagePublicIds,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      category: category ?? this.category,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      upvotedBy: upvotedBy ?? this.upvotedBy,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      isSponsoredContent: isSponsoredContent ?? this.isSponsoredContent,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }
}
