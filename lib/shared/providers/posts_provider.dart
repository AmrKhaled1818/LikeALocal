import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/posts_repo.dart';

class PostsProvider extends ChangeNotifier {
  final PostsRepo _repo = PostsRepo();

  List<PostModel> _feedPosts = [];
  bool _isLoading = true;
  String? _error;

  List<PostModel> get feedPosts => _feedPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PostsProvider() {
    _init();
  }

  void _init() {
    _repo.getFeedPosts().listen(
      (posts) {
        _feedPosts = posts;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<String?> createPost(PostModel post, File? imageFile) async {
    try {
      return await _repo.createPost(post, imageFile);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> upvotePost(
      String postId, String voterId, String authorId) async {
    try {
      await _repo.upvotePost(postId, voterId, authorId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> downvotePost(String postId) async {
    try {
      await _repo.downvotePost(postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> savePost(String userId, String postId) async {
    try {
      await _repo.savePost(userId, postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> unsavePost(String userId, String postId) async {
    try {
      await _repo.unsavePost(userId, postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> isPostSaved(String userId, String postId) async {
    return await _repo.isPostSaved(userId, postId);
  }

  Future<List<PostModel>> getSavedPosts(String userId) async {
    return await _repo.getSavedPosts(userId);
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    return await _repo.getUserPosts(userId);
  }

  PostModel? getPostById(String id) {
    try {
      return _feedPosts.firstWhere((p) => p.postId == id);
    } catch (_) {
      return null;
    }
  }

  void refresh() {
    _isLoading = true;
    notifyListeners();
    _init();
  }
}
