import 'dart:async' show StreamSubscription, TimeoutException, Timer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../data/repositories/auth_repo.dart';
import '../../data/repositories/user_repo.dart';
import '../../data/models/user_model.dart';
import '../../data/services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepo _authRepo = AuthRepo();
  final UserRepo _userRepo = UserRepo();

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  // Subscription reference so we can cancel it on sign-out / re-login
  StreamSubscription<UserModel?>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  bool _notifInitialized = false;
  Timer? _heartbeatTimer;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _firebaseUser != null;
  String get uid => _firebaseUser?.uid ?? '';

  AuthProvider() {
    _authRepo.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    await _userSub?.cancel();
    await _notifSub?.cancel();
    _heartbeatTimer?.cancel();
    _userSub = null;
    _notifSub = null;
    _heartbeatTimer = null;

    _firebaseUser = user;
    if (user != null) {
      _userSub = _userRepo.watchUser(user.uid).listen((model) {
        _userModel = model;
        notifyListeners();
      });
      try {
        await _userRepo.setOnlineStatus(user.uid, true);
      } catch (_) {}

      // Heartbeat: update lastSeen every 60s so isReallyOnline stays accurate
      // even if the app is force-killed (lastSeen goes stale → shows offline after 2 min)
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (_firebaseUser != null) {
          _userRepo.updateUser(_firebaseUser!.uid, {'lastSeen': Timestamp.now()}).catchError((_) {});
        }
      });
      try {
        final token = await NotificationService.requestPermissionAndGetToken();
        if (token != null) {
          await _userRepo.updateFcmToken(user.uid, token);
        }
      } catch (_) {}

      _notifInitialized = false;
      _notifSub = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .limit(10)
          .snapshots()
          .listen((snap) {
        if (!_notifInitialized) {
          _notifInitialized = true;
          return; // skip pre-existing notifications on login
        }
        // Only react to newly added docs; filter type client-side (avoids composite index)
        // 'message' is handled by ChatProvider to avoid duplicates and support open-chat suppression
        const pushableTypes = {'upvote', 'superuser', 'comment', 'nearby'};
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          final type = data?['type'] as String?;
          if (data == null || !pushableTypes.contains(type)) continue;
          final title = (data['title'] as String?) ?? 'LikeALocal';
          final body = (data['body'] as String?) ?? '';
          NotificationService.showLocalNotification(title, body);
        }
      }, onError: (_) {});
    } else {
      _userModel = null;
    }
    notifyListeners();
  }

  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'user-not-found':
        return 'No account found with this email';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please enter a valid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'network-request-failed':
        return 'No internet connection. Check your network';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepo.signIn(email, password)
          .timeout(const Duration(seconds: 15));
      _clearError();
      return true;
    } on TimeoutException {
      _setError('Connection timed out. Check your network and try again.');
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyAuthError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(
      String email, String password, String username) async {
    _setLoading(true);
    try {
      await _authRepo.register(email, password, username)
          .timeout(const Duration(seconds: 15));
      _clearError();
      return true;
    } on TimeoutException {
      _setError('Connection timed out. Check your network and try again.');
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyAuthError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      await _authRepo.signInWithGoogle();
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyAuthError(e));
      return false;
    } catch (e) {
      if (e.toString().contains('cancelled')) return false;
      _setError('Google sign-in failed. Please try again');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    final uid = _firebaseUser?.uid;
    if (uid != null) {
      try { await _userRepo.setOnlineStatus(uid, false); } catch (_) {}
    }
    await _authRepo.signOut();
  }

  Future<void> setOnline(bool online) async {
    final uid = _firebaseUser?.uid;
    if (uid == null) return;
    try { await _userRepo.setOnlineStatus(uid, online); } catch (_) {}
  }

  Future<bool> deleteAccount() async {
    _setLoading(true);
    try {
      final uid = _firebaseUser?.uid;
      if (uid == null) return false;
      await _userRepo.deleteUserData(uid);
      await _firebaseUser?.delete();
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.code == 'requires-recent-login'
          ? 'Please log out and log back in, then try again'
          : _friendlyAuthError(e));
      return false;
    } catch (e) {
      _setError('Failed to delete account. Please try again');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authRepo.resetPassword(email);
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_friendlyAuthError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _notifSub?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
