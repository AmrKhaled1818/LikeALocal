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
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return posts;
    });
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromMap(doc.data()!, doc.id);
  }

  Stream<PostModel?> watchPost(String postId) {
    return _db.collection('posts').doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PostModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<PostModel> updatePost(PostModel post, File? newImageFile) async {
    String imageUrl = post.imageUrl;
    String imagePublicId = post.imagePublicId;

    if (newImageFile != null) {
      final result = await _cloudinary.uploadImage(newImageFile);
      imageUrl = result.imageUrl;
      imagePublicId = result.imagePublicId;
    }

    await _db.collection('posts').doc(post.postId).update({
      'title': post.title,
      'description': post.description,
      'location': post.location,
      'lat': post.lat,
      'lng': post.lng,
      'category': post.category,
      'localTips': post.localTips,
      'recommendedDishes': post.recommendedDishes,
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
    });

    return PostModel(
      postId: post.postId,
      userId: post.userId,
      username: post.username,
      userAvatarUrl: post.userAvatarUrl,
      isSuperUser: post.isSuperUser,
      title: post.title,
      description: post.description,
      location: post.location,
      lat: post.lat,
      lng: post.lng,
      category: post.category,
      localTips: post.localTips,
      recommendedDishes: post.recommendedDishes,
      imageUrl: imageUrl,
      imagePublicId: imagePublicId,
      upvotes: post.upvotes,
      downvotes: post.downvotes,
      upvotedBy: post.upvotedBy,
      commentCount: post.commentCount,
      createdAt: post.createdAt,
    );
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

  Future<PostModel> createPost(PostModel post, File? imageFile) async {
    final ref = _db.collection('posts').doc();
    String imageUrl = post.imageUrl;
    String imagePublicId = post.imagePublicId;

    if (imageFile != null) {
      final result = await _cloudinary.uploadImage(imageFile);
      imageUrl = result.imageUrl;
      imagePublicId = result.imagePublicId;
    }

    final newPost = post.copyWith(
        postId: ref.id, imageUrl: imageUrl, imagePublicId: imagePublicId);
    final data = newPost.toMap();
    await ref.set(data);
    await _userRepo.addKarma(post.userId, 10);
    return newPost;
  }

  Future<void> upvotePost(String postId, String voterId, String authorId, String voterName) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({
      'upvotes': FieldValue.increment(1),
      'upvotedBy': FieldValue.arrayUnion([voterName]),
    });
    await _userRepo.addKarma(authorId, 2);
    await _createNotification(NotificationModel(
      notifId: '',
      userId: authorId,
      type: 'upvote',
      title: '$voterName upvoted your post',
      body: '$voterName just upvoted your post!',
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
