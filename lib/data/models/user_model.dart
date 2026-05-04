import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String avatarUrl;
  final String bio;
  final String location;
  final int karma;
  final bool isSuperUser;
  final double contributionScore;
  final bool chatEnabled;
  final Map<String, dynamic>? chatSchedule;
  final Map<String, dynamic> preferences;
  final Timestamp joinedAt;
  final String fcmToken;

  UserModel({
    required this.uid,
    required this.username,
    this.avatarUrl = '',
    this.bio = '',
    this.location = '',
    this.karma = 0,
    this.isSuperUser = false,
    this.contributionScore = 0.0,
    this.chatEnabled = true,
    this.chatSchedule,
    Map<String, dynamic>? preferences,
    Timestamp? joinedAt,
    this.fcmToken = '',
  })  : preferences = preferences ??
            {'budget': '', 'atmosphere': '', 'favCategories': []},
        joinedAt = joinedAt ?? Timestamp.now();

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      bio: map['bio'] ?? '',
      location: map['location'] ?? '',
      karma: map['karma'] ?? 0,
      isSuperUser: map['isSuperUser'] ?? false,
      contributionScore: (map['contributionScore'] ?? 0.0).toDouble(),
      chatEnabled: map['chatEnabled'] ?? true,
      chatSchedule: map['chatSchedule'],
      preferences: map['preferences'] ??
          {'budget': '', 'atmosphere': '', 'favCategories': []},
      joinedAt: map['joinedAt'] ?? Timestamp.now(),
      fcmToken: map['fcmToken'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'location': location,
      'karma': karma,
      'isSuperUser': isSuperUser,
      'contributionScore': contributionScore,
      'chatEnabled': chatEnabled,
      'chatSchedule': chatSchedule,
      'preferences': preferences,
      'joinedAt': joinedAt,
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? avatarUrl,
    String? bio,
    String? location,
    int? karma,
    bool? isSuperUser,
    double? contributionScore,
    bool? chatEnabled,
    Map<String, dynamic>? chatSchedule,
    Map<String, dynamic>? preferences,
    Timestamp? joinedAt,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      karma: karma ?? this.karma,
      isSuperUser: isSuperUser ?? this.isSuperUser,
      contributionScore: contributionScore ?? this.contributionScore,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      chatSchedule: chatSchedule ?? this.chatSchedule,
      preferences: preferences ?? this.preferences,
      joinedAt: joinedAt ?? this.joinedAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
