import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthRepo {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register(
      String email, String password, String username) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _createUserDoc(cred.user!, username);
  }

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      // On web, use Firebase Auth popup — no clientId needed
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      final cred = await _auth.signInWithPopup(provider);
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      if (!doc.exists) {
        await _createUserDoc(
            cred.user!, cred.user!.displayName ?? cred.user!.email?.split('@')[0] ?? 'User');
      }
      return cred;
    }

    // Mobile flow — uses google_sign_in package
    final googleSignIn =
        _googleSignIn ??= GoogleSignIn(scopes: ['email', 'profile']);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    final doc = await _db.collection('users').doc(cred.user!.uid).get();
    if (!doc.exists) {
      await _createUserDoc(
          cred.user!, googleUser.displayName ?? googleUser.email.split('@')[0]);
    }
    return cred;
  }

  Future<void> signOut() async {
    if (!kIsWeb && _googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> _createUserDoc(User user, String username) async {
    final model = UserModel(
      uid: user.uid,
      username: username,
      avatarUrl: user.photoURL ?? '',
      joinedAt: Timestamp.now(),
    );
    await _db.collection('users').doc(user.uid).set(model.toMap());
  }

  Future<UserModel?> getUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }
}
