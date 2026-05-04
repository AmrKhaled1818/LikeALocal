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
    _firebaseUser = user;
    if (user != null) {
      _userRepo.watchUser(user.uid).listen((model) {
        _userModel = model;
        notifyListeners();
      });
      try {
        final token = await NotificationService.requestPermissionAndGetToken();
        if (token != null) {
          await _userRepo.updateFcmToken(user.uid, token);
        }
      } catch (_) {}
    } else {
      _userModel = null;
    }
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepo.signIn(email, password);
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Sign in failed');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(
      String email, String password, String username) async {
    _setLoading(true);
    try {
      await _authRepo.register(email, password, username);
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Registration failed');
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
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _authRepo.signOut();
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    try {
      await _authRepo.resetPassword(email);
      _clearError();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'Reset failed');
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
}
