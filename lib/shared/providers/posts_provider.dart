import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/post_model.dart';
import '../../data/models/comment_model.dart';
import '../../data/repositories/posts_repo.dart';
import '../../core/services/proximity_service.dart';

class PostsProvider extends ChangeNotifier {
  final PostsRepo _repo = PostsRepo();

  List<PostModel> _feedPosts = [];
  // Full unfiltered list from a persistent stream — used by map & search
  // so they always see ALL posts regardless of feed pagination.
  List<PostModel> _allPosts = [];
  StreamSubscription<List<PostModel>>? _allPostsSub;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String? _error;

  // Saved-post IDs cache — avoids per-card Firestore reads
  Set<String> _savedPostIds = {};
  bool _savedIdsLoaded = false;

  // Ordering option
  bool _showSuperUsersFirst = true;
  bool get showSuperUsersFirst => _showSuperUsersFirst;

  void toggleSuperUsersFirst() {
    _showSuperUsersFirst = !_showSuperUsersFirst;
    notifyListeners();
  }

  // Mood-based home screen — persisted per device.
  static const _moodPrefsKey = 'home_mood';
  String _mood = '';

  static const _pageSize = 10;

  List<PostModel> get feedPosts => _feedPosts;
  /// All posts from the real-time stream — no pagination limit.
  /// Falls back to the paginated list while the stream is loading.
  List<PostModel> get allPosts => _allPosts.isEmpty ? _feedPosts : _allPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get savedIdsLoaded => _savedIdsLoaded;
  int get savedPostCount => _savedPostIds.length;
  String get mood => _mood;

  PostsProvider() {
    _loadMood();
    _loadFirstPage();
    _subscribeAllPosts();
  }

  void _subscribeAllPosts() {
    _allPostsSub = _repo.getFeedPosts().listen((posts) {
      _allPosts = posts;
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _allPostsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadMood() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final m = prefs.getString(_moodPrefsKey) ?? '';
      if (m.isNotEmpty && m != _mood) {
        _mood = m;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setMood(String mood) async {
    if (mood == _mood) return;
    _mood = mood;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mood.isEmpty) {
        await prefs.remove(_moodPrefsKey);
      } else {
        await prefs.setString(_moodPrefsKey, mood);
      }
    } catch (_) {}
  }

  /// Feed ordered for display.
  /// Toggle OFF → pure newest-first (no scoring).
  /// Toggle ON  → super user posts first (newest-first within group),
  ///              then everyone else (newest-first). No vibe scoring in either mode.
  List<PostModel> rankedFeed([Map<String, dynamic>? prefs]) {
    final ranked = List<PostModel>.from(_feedPosts);

    if (!_showSuperUsersFirst) {
      ranked.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ranked;
    }

    ranked.sort((a, b) {
      if (a.isSuperUser != b.isSuperUser) return a.isSuperUser ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return ranked;
  }

  Future<void> _loadFirstPage() async {
    _isLoading = true;
    _error = null;
    _hasMore = true;
    _lastDoc = null;
    notifyListeners();
    try {
      final (posts, lastDoc) = await _repo.getFeedPage(limit: _pageSize);
      _feedPosts = posts;
      _lastDoc = lastDoc;
      _hasMore = posts.length == _pageSize;
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

  Future<String?> createPost(
    PostModel post,
    List<XFile> imageFiles, {
    XFile? videoFile,
  }) async {
    try {
      final newPost =
          await _repo.createPost(post, imageFiles, videoFile: videoFile);
      _feedPosts = [newPost, ..._feedPosts];
      notifyListeners();
      return newPost.postId;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updatePost(PostModel updatedPost, List<XFile> newImageFiles) async {
    try {
      final result = await _repo.updatePost(updatedPost, newImageFiles);
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

  Future<bool> upvotePost(
      String postId, String voterId, String authorId, String voterName) async {
    final postIndex = _feedPosts.indexWhere((p) => p.postId == postId);
    if (postIndex != -1) {
      final post = _feedPosts[postIndex];
      if (post.upvotedBy.contains(voterName)) return false; // already voted

      final updatedUpvoters = List<String>.from(post.upvotedBy)..add(voterName);
      _feedPosts = List<PostModel>.from(_feedPosts);
      _feedPosts[postIndex] = post.copyWith(
        upvotes: post.upvotes + 1,
        upvotedBy: updatedUpvoters,
      );
      notifyListeners();
    }

    try {
      await _repo.upvotePost(postId, voterId, authorId, voterName);
      return true;
    } catch (e) {
      if (postIndex != -1) {
        final post = _feedPosts[postIndex];
        final revertedUpvoters = List<String>.from(post.upvotedBy)
          ..remove(voterName);
        _feedPosts = List<PostModel>.from(_feedPosts);
        _feedPosts[postIndex] = post.copyWith(
          upvotes: (post.upvotes - 1).clamp(0, 999999),
          upvotedBy: revertedUpvoters,
        );
        notifyListeners();
      }
      _error = e.toString();
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _repo.deletePost(postId);
      _feedPosts.removeWhere((p) => p.postId == postId);
      _savedPostIds.remove(postId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeUpvote(String postId, String voterName) async {
    final postIndex = _feedPosts.indexWhere((p) => p.postId == postId);
    if (postIndex != -1) {
      final post = _feedPosts[postIndex];
      final updatedUpvoters = List<String>.from(post.upvotedBy)..remove(voterName);
      _feedPosts = List<PostModel>.from(_feedPosts);
      _feedPosts[postIndex] = post.copyWith(
        upvotes: (post.upvotes - 1).clamp(0, 999999),
        upvotedBy: updatedUpvoters,
      );
      notifyListeners();
    }
    try {
      await _repo.removeUpvote(postId, voterName);
      return true;
    } catch (e) {
      if (postIndex != -1) {
        final post = _feedPosts[postIndex];
        final revertedUpvoters = List<String>.from(post.upvotedBy)..add(voterName);
        _feedPosts = List<PostModel>.from(_feedPosts);
        _feedPosts[postIndex] = post.copyWith(
          upvotes: post.upvotes + 1,
          upvotedBy: revertedUpvoters,
        );
        notifyListeners();
      }
      _error = e.toString();
      return false;
    }
  }

  Future<bool> removeDownvote(String postId) async {
    final postIndex = _feedPosts.indexWhere((p) => p.postId == postId);
    if (postIndex != -1) {
      final post = _feedPosts[postIndex];
      _feedPosts = List<PostModel>.from(_feedPosts);
      _feedPosts[postIndex] = post.copyWith(
        downvotes: (post.downvotes - 1).clamp(0, 999999),
      );
      notifyListeners();
    }
    try {
      await _repo.removeDownvote(postId);
      return true;
    } catch (e) {
      if (postIndex != -1) {
        final post = _feedPosts[postIndex];
        _feedPosts = List<PostModel>.from(_feedPosts);
        _feedPosts[postIndex] = post.copyWith(downvotes: post.downvotes + 1);
        notifyListeners();
      }
      _error = e.toString();
      return false;
    }
  }

  Future<bool> downvotePost(String postId) async {
    final postIndex = _feedPosts.indexWhere((p) => p.postId == postId);
    if (postIndex != -1) {
      final post = _feedPosts[postIndex];
      _feedPosts = List<PostModel>.from(_feedPosts);
      _feedPosts[postIndex] = post.copyWith(downvotes: post.downvotes + 1);
      notifyListeners();
    }
    try {
      await _repo.downvotePost(postId);
      return true;
    } catch (e) {
      if (postIndex != -1) {
        final post = _feedPosts[postIndex];
        _feedPosts = List<PostModel>.from(_feedPosts);
        _feedPosts[postIndex] = post.copyWith(
            downvotes: (post.downvotes - 1).clamp(0, 999999));
        notifyListeners();
      }
      _error = e.toString();
      return false;
    }
  }

  Future<bool> checkInPost(String postId, String userId) async {
    final idx = _feedPosts.indexWhere((p) => p.postId == postId);
    if (idx != -1) {
      final post = _feedPosts[idx];
      final updated = Map<int, int>.from(post.checkinsByHour);
      final h = DateTime.now().hour;
      updated[h] = (updated[h] ?? 0) + 1;
      _feedPosts = List<PostModel>.from(_feedPosts);
      _feedPosts[idx] = post.copyWith(
        checkinsByHour: updated,
        lastCheckinAt: Timestamp.now(),
      );
      notifyListeners();
    }
    try {
      await _repo.checkIn(postId, userId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<void> cacheBestTime(String postId, String hint) async {
    final idx = _feedPosts.indexWhere((p) => p.postId == postId);
    if (idx != -1) {
      _feedPosts = List<PostModel>.from(_feedPosts);
      _feedPosts[idx] = _feedPosts[idx].copyWith(bestTime: hint);
      notifyListeners();
    }
    await _repo.updateBestTime(postId, hint);
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

  // ── Saved-post cache ──────────────────────────────────────────────────────

  Future<void> loadSavedIds(String userId) async {
    if (_savedIdsLoaded) return;
    try {
      final ids = await _repo.getSavedPostIds(userId);
      _savedPostIds = ids.toSet();
      _savedIdsLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  bool isPostSavedLocally(String postId) => _savedPostIds.contains(postId);

  Future<void> savePost(String userId, String postId) async {
    _savedPostIds.add(postId);
    notifyListeners();
    try {
      await _repo.savePost(userId, postId);
      _updateProximityCache();
    } catch (e) {
      _savedPostIds.remove(postId);
      notifyListeners();
      _error = e.toString();
    }
  }

  void _updateProximityCache() {
    final saved = _feedPosts
        .where((p) => _savedPostIds.contains(p.postId))
        .map((p) => {
              'postId': p.postId,
              'title': p.title,
              'lat': p.lat,
              'lng': p.lng,
            })
        .toList();
    ProximityService.cacheSavedPosts(saved);
  }

  Future<void> unsavePost(String userId, String postId) async {
    _savedPostIds.remove(postId);
    notifyListeners();
    try {
      await _repo.unsavePost(userId, postId);
    } catch (e) {
      _savedPostIds.add(postId);
      notifyListeners();
      _error = e.toString();
    }
  }

  Future<bool> isPostSaved(String userId, String postId) async {
    if (_savedIdsLoaded) return _savedPostIds.contains(postId);
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
    _savedIdsLoaded = false;
    _savedPostIds = {};
    _loadFirstPage();
  }

  void resetSavedCache() {
    _savedIdsLoaded = false;
    _savedPostIds = {};
  }
}
