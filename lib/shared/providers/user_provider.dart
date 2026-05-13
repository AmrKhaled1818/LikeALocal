import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/posts_repo.dart';
import '../../data/repositories/user_repo.dart';
import '../../data/services/cloudinary_service.dart';

class UserProvider extends ChangeNotifier {
  final UserRepo _repo = UserRepo();

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  void setUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  void startWatching(String uid) {
    _repo.watchUser(uid).listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  Future<void> updateProfile(
    String uid, {
    String? username,
    String? bio,
    String? location,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (username != null && username.isNotEmpty) data['username'] = username;
    if (bio != null) data['bio'] = bio;
    if (location != null) data['location'] = location;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (data.isNotEmpty) await _repo.updateUser(uid, data);
  }

  Future<void> updateAvatar(String uid, XFile imageFile) async {
    final cloudinary = CloudinaryService();
    final result = await cloudinary.uploadAvatar(imageFile);
    await _repo.updateUser(uid, {'avatarUrl': result.imageUrl});
    await PostsRepo().updateUserAvatarOnPosts(uid, result.imageUrl);
  }

  Future<void> updateChatEnabled(bool enabled) async {
    if (_currentUser == null) return;
    await _repo.updateChatEnabled(_currentUser!.uid, enabled);
  }

  Future<void> updatePreferences(Map<String, dynamic> prefs) async {
    if (_currentUser == null) return;
    await _repo.updatePreferences(_currentUser!.uid, prefs);
  }

  Future<void> updateChatSchedule(Map<String, dynamic> schedule) async {
    if (_currentUser == null) return;
    await _repo.updateChatSchedule(_currentUser!.uid, schedule);
  }

  Future<void> updateField(String uid, Map<String, dynamic> fields) async {
    await _repo.updateUser(uid, fields);
  }

  Future<UserModel?> getUser(String uid) async {
    return await _repo.getUser(uid);
  }
}
