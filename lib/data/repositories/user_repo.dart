import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<void> addKarma(String uid, int amount) async {
    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final current = snap.data()!;
      final newKarma = (current['karma'] ?? 0) + amount;
      final newScore = (newKarma.toDouble()).clamp(0.0, 100.0);
      final isSuperUser = newKarma >= 100;
      tx.update(ref, {
        'karma': newKarma,
        'contributionScore': newScore,
        'isSuperUser': isSuperUser,
      });
    });
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({'fcmToken': token});
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
