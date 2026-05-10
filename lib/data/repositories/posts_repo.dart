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

  Future<PostModel> updatePost(PostModel post, List<File> newImageFiles) async {
    List<String> imageUrls = List<String>.from(post.imageUrls);
    List<String> imagePublicIds = List<String>.from(post.imagePublicIds);

    if (newImageFiles.isNotEmpty) {
      final results = await _cloudinary.uploadImages(newImageFiles);
      imageUrls.addAll(results.map((r) => r.imageUrl));
      imagePublicIds.addAll(results.map((r) => r.imagePublicId));
    }

    final firstUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
    final firstId = imagePublicIds.isNotEmpty ? imagePublicIds.first : '';

    await _db.collection('posts').doc(post.postId).update({
      'title': post.title,
      'description': post.description,
      'location': post.location,
      'lat': post.lat,
      'lng': post.lng,
      'category': post.category,
      'localTips': post.localTips,
      'recommendedDishes': post.recommendedDishes,
      'imageUrl': firstUrl,
      'imagePublicId': firstId,
      'imageUrls': imageUrls,
      'imagePublicIds': imagePublicIds,
    });

    return post.copyWith(
      imageUrl: firstUrl,
      imagePublicId: firstId,
      imageUrls: imageUrls,
      imagePublicIds: imagePublicIds,
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

  Future<PostModel> createPost(PostModel post, List<File> imageFiles) async {
    final ref = _db.collection('posts').doc();
    List<String> imageUrls = [];
    List<String> imagePublicIds = [];

    if (imageFiles.isNotEmpty) {
      final results = await _cloudinary.uploadImages(imageFiles);
      imageUrls = results.map((r) => r.imageUrl).toList();
      imagePublicIds = results.map((r) => r.imagePublicId).toList();
    }

    final newPost = post.copyWith(
      postId: ref.id,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
      imagePublicId: imagePublicIds.isNotEmpty ? imagePublicIds.first : '',
      imageUrls: imageUrls,
      imagePublicIds: imagePublicIds,
    );
    await ref.set(newPost.toMap());
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
    // Only award karma and notify when another user upvotes (not self-upvote)
    if (voterId != authorId) {
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
  }

  Future<void> updateUserAvatarOnPosts(String userId, String avatarUrl) async {
    final snap = await _db
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'userAvatarUrl': avatarUrl});
    }
    await batch.commit();
  }

  Future<void> deletePost(String postId) async {
    // Delete all comments first
    final comments = await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .get();
    final batch = _db.batch();
    for (final doc in comments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('posts').doc(postId));
    await batch.commit();
  }

  Future<void> removeUpvote(String postId, String voterName) async {
    await _db.collection('posts').doc(postId).update({
      'upvotes': FieldValue.increment(-1),
      'upvotedBy': FieldValue.arrayRemove([voterName]),
    });
  }

  Future<void> downvotePost(String postId) async {
    await _db
        .collection('posts')
        .doc(postId)
        .update({'downvotes': FieldValue.increment(1)});
  }

  Future<void> removeDownvote(String postId) async {
    await _db.collection('posts').doc(postId).update({
      'downvotes': FieldValue.increment(-1),
    });
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

  Future<List<String>> getSavedPostIds(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  Future<List<PostModel>> getSavedPosts(String userId) async {
    final ids = await getSavedPostIds(userId);
    if (ids.isEmpty) return [];
    // Batch reads with whereIn (max 30 per query) instead of N individual reads
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 30) {
      chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }
    final results = await Future.wait(chunks.map((chunk) =>
        _db.collection('posts').where(FieldPath.documentId, whereIn: chunk).get()));
    return results
        .expand((snap) => snap.docs.map((d) => PostModel.fromMap(d.data(), d.id)))
        .toList();
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

  Future<void> toggleCommentLike(
      String postId, String commentId, String userId, bool add) async {
    await _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'likedBy': add
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
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
