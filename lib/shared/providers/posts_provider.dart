import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/posts_repo.dart';
import '../../data/seed_places.dart';

class PostsProvider extends ChangeNotifier {
  final PostsRepo _repo = PostsRepo();

  List<PostModel> _feedPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String? _error;

  static const _pageSize = 10;

  List<PostModel> get feedPosts => _feedPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  PostsProvider() {
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    _isLoading = true;
    _error = null;
    _hasMore = true;
    _lastDoc = null;
    notifyListeners();
    try {
      // Seed curated places to Firestore (skips existing ones)
      SeedPlaces.seedToFirestore().catchError((_) => 0);

      final (posts, lastDoc) = await _repo.getFeedPage(limit: _pageSize);
      _feedPosts = posts;
      _lastDoc = lastDoc;
      _hasMore = posts.length == _pageSize;

      // Merge any seed places not yet in the paginated feed so they
      // always appear on the map regardless of pagination state.
      final existingIds = _feedPosts.map((p) => p.postId).toSet();
      for (final seed in SeedPlaces.all) {
        if (!existingIds.contains(seed.postId)) {
          _feedPosts.add(seed);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final (posts, lastDoc) =
          await _repo.getFeedPage(limit: _pageSize, startAfter: _lastDoc);
      _feedPosts = [..._feedPosts, ...posts];
      _lastDoc = lastDoc;
      _hasMore = posts.length == _pageSize;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<String?> createPost(PostModel post, File? imageFile) async {
    try {
      final newPost = await _repo.createPost(post, imageFile);
      _feedPosts = [newPost, ..._feedPosts];
      notifyListeners();
      return newPost.postId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updatePost(PostModel updatedPost, File? newImageFile) async {
    try {
      final result = await _repo.updatePost(updatedPost, newImageFile);
      final index = _feedPosts.indexWhere((p) => p.postId == updatedPost.postId);
      if (index != -1) {
        _feedPosts[index] = result;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> upvotePost(
      String postId, String voterId, String authorId, String voterName) async {
    try {
      await _repo.upvotePost(postId, voterId, authorId, voterName);
      
      // Update local state upvotedBy list for immediate UI feedback
      final postIndex = _feedPosts.indexWhere((p) => p.postId == postId);
      if (postIndex != -1) {
        final post = _feedPosts[postIndex];
        if (!post.upvotedBy.contains(voterName)) {
          final updatedUpvoters = List<String>.from(post.upvotedBy)..add(voterName);
          _feedPosts[postIndex] = post.copyWith(
            upvotes: post.upvotes + 1,
            upvotedBy: updatedUpvoters,
          );
          notifyListeners();
        }
      }
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

  Future<void> addComment(CommentModel comment) async {
    try {
      await _repo.addComment(comment);
      final index = _feedPosts.indexWhere((p) => p.postId == comment.postId);
      if (index != -1) {
        final post = _feedPosts[index];
        _feedPosts[index] = post.copyWith(commentCount: post.commentCount + 1);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
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
    _loadFirstPage();
  }
}
