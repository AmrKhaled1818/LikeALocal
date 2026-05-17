import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Karma at which a user is auto-promoted to "Super User".
  static const int superUserKarmaThreshold = 100;

  Stream<UserModel?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!);
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  /// Awards [amount] karma. Auto-promotes the user to Super User once their
  /// karma crosses [superUserKarmaThreshold] and fires a one-time in-app
  /// notification. Returns true if this award triggered the promotion.
  Future<bool> addKarma(String uid, int amount) async {
    final ref = _db.collection('users').doc(uid);
    bool promoted = false;
    String username = '';
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = snap.data()!;
      username = (current['username'] as String?) ?? '';
      final wasSuperUser = current['isSuperUser'] == true;
      final newKarma = (current['karma'] ?? 0) + amount;
      final isSuperUser = wasSuperUser || newKarma >= superUserKarmaThreshold;
      promoted = !wasSuperUser && isSuperUser;
      tx.update(ref, {
        'karma': newKarma,
        'contributionScore': newKarma.toDouble(),
        'isSuperUser': isSuperUser,
      });
    });

    if (promoted) {
      try {
        // Stamp existing posts so they immediately render with the Super User badge.
        final posts =
            await _db.collection('posts').where('userId', isEqualTo: uid).get();
        if (posts.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final doc in posts.docs) {
            batch.update(doc.reference, {'isSuperUser': true});
          }
          await batch.commit();
        }
        final notifRef = _db.collection('notifications').doc();
        await notifRef.set({
          'notifId': notifRef.id,
          'userId': uid,
          'type': 'superuser',
          'title': 'You\'re now a Super User! 🎉',
          'body': 'Thanks for being an awesome local'
              '${username.isNotEmpty ? ', $username' : ''} — your posts now '
              'appear first and the AI daily limit no longer applies.',
          'postId': null,
          'read': false,
          'createdAt': Timestamp.now(),
        });
      } catch (_) {}
    }
    return promoted;
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<void> setOnlineStatus(String uid, bool online) async {
    final data = <String, dynamic>{'isOnline': online};
    if (!online) data['lastSeen'] = Timestamp.now();
    await _db.collection('users').doc(uid).update(data);
  }

  Future<void> updateChatEnabled(String uid, bool enabled) async {
    await _db.collection('users').doc(uid).update({'chatEnabled': enabled});
  }

  Future<void> updatePreferences(
      String uid, Map<String, dynamic> prefs) async {
    await _db.collection('users').doc(uid).update({'preferences': prefs});
  }

  Future<void> updateChatSchedule(
      String uid, Map<String, dynamic> schedule) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'chatSchedule': schedule});
  }

  Future<void> deleteUserData(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final prefix = query.trim();
    if (prefix.isEmpty) return [];
    
    final upper = '$prefix\uf8ff';
    final snap = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: prefix)
        .where('username', isLessThanOrEqualTo: upper)
        .limit(20)
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }
}
