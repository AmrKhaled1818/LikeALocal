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
  final bool isPremium;
  final int pinsUsed;
  final int postsCreated;
  final bool isOnline;
  final Timestamp? lastSeen;

  /// True only if both the flag is set AND the last heartbeat was within 2 minutes.
  /// This prevents stale "Online" status when the app is force-killed.
  bool get isReallyOnline {
    if (!isOnline) return false;
    if (lastSeen == null) return true;
    return DateTime.now().difference(lastSeen!.toDate()).inMinutes < 2;
  }

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
    this.isPremium = false,
    this.pinsUsed = 0,
    this.postsCreated = 0,
    this.isOnline = false,
    this.lastSeen,
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
      isPremium: map['isPremium'] ?? false,
      pinsUsed: map['pinsUsed'] ?? 0,
      postsCreated: map['postsCreated'] ?? 0,
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] as Timestamp?,
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
      'isPremium': isPremium,
      'pinsUsed': pinsUsed,
      'postsCreated': postsCreated,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
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
    bool? isPremium,
    int? pinsUsed,
    int? postsCreated,
    bool? isOnline,
    Timestamp? lastSeen,
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
      isPremium: isPremium ?? this.isPremium,
      pinsUsed: pinsUsed ?? this.pinsUsed,
      postsCreated: postsCreated ?? this.postsCreated,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
