import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/message_model.dart';
import '../services/cloudinary_service.dart';
import 'user_repo.dart';

class PostsRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();
  final UserRepo _userRepo = UserRepo();

  // Feed — paginated (single-field orderBy avoids composite index requirement)
  Future<(List<PostModel>, DocumentSnapshot?)> getFeedPage({
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snap = await query.get();
    final posts =
        snap.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList();
    // Sort super user posts to top client-side
    posts.sort((a, b) {
      if (a.isSuperUser != b.isSuperUser) return a.isSuperUser ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    return (posts, lastDoc);
  }

  // Keep stream for map screen (real-time all posts)
  Stream<List<PostModel>> getFeedPosts() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final posts =
          snap.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList();
      posts.sort((a, b) {
        if (a.isSuperUser != b.isSuperUser) return a.isSuperUser ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return posts;
    });
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromMap(doc.data()!, doc.id);
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    // No orderBy to avoid composite index — sort client-side
    final snap = await _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();
    final posts =
        snap.docs.map((d) => PostModel.fromMap(d.data(), d.id)).toList();
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<String> createPost(PostModel post, File? imageFile) async {
    final ref = _db.collection('posts').doc();
    String imageUrl = post.imageUrl;
    String imagePublicId = post.imagePublicId;

    if (imageFile != null) {
      final result = await _cloudinary.uploadImage(imageFile);
      imageUrl = result.imageUrl;
      imagePublicId = result.imagePublicId;
    }

    final data =
        post.copyWith(imageUrl: imageUrl, imagePublicId: imagePublicId).toMap();
    data['postId'] = ref.id;
    await ref.set(data);
    await _userRepo.addKarma(post.userId, 10);
    return ref.id;
  }

  Future<void> upvotePost(String postId, String voterId, String authorId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'upvotes': FieldValue.increment(1)});
    await _userRepo.addKarma(authorId, 2);
    await _createNotification(NotificationModel(
      notifId: '',
      userId: authorId,
      type: 'upvote',
      title: 'Someone upvoted your post',
      body: 'Your post received an upvote!',
      postId: postId,
    ));
  }

  Future<void> downvotePost(String postId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'downvotes': FieldValue.increment(1)});
  }

  Future<void> savePost(String userId, String postId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .set({'postId': postId, 'savedAt': Timestamp.now()});
  }

  Future<void> unsavePost(String userId, String postId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .delete();
  }

  Future<bool> isPostSaved(String userId, String postId) async {
    final doc = await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .get();
    return doc.exists;
  }

  Future<List<PostModel>> getSavedPosts(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .get();
    final ids = snap.docs.map((d) => d.id).toList();
    if (ids.isEmpty) return [];
    final posts = await Future.wait(ids.map((id) => getPost(id)));
    return posts.whereType<PostModel>().toList();
  }

  // Comments
  Stream<List<CommentModel>> getComments(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommentModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> addComment(CommentModel comment) async {
    final ref = _db
        .collection('posts')
        .doc(comment.postId)
        .collection('comments')
        .doc();
    final data = comment.toMap();
    data['commentId'] = ref.id;
    await ref.set(data);
    await _db
        .collection('posts')
        .doc(comment.postId)
        .update({'commentCount': FieldValue.increment(1)});
    await _userRepo.addKarma(comment.userId, 1);
  }

  Future<void> editComment(
      String postId, String commentId, String newContent) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'content': newContent, 'editedAt': Timestamp.now()});
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
    await _db
        .collection('posts')
        .doc(postId)
        .update({'commentCount': FieldValue.increment(-1)});
  }

  Future<void> _createNotification(NotificationModel notif) async {
    final ref = _db.collection('notifications').doc();
    final data = notif.toMap();
    data['notifId'] = ref.id;
    await ref.set(data);
  }
}
