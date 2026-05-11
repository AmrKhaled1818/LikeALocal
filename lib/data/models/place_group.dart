import 'dart:math' as math;
import 'post_model.dart';

class PlaceGroup {
  final String placeKey;
  final List<PostModel> posts;

  const PlaceGroup({required this.placeKey, required this.posts});

  PostModel get representative =>
      posts.reduce((a, b) => a.upvotes >= b.upvotes ? a : b);

  String get coverImageUrl {
    final urls = representative.allImageUrls;
    return urls.isNotEmpty ? urls.first : '';
  }

  String get displayTitle => representative.title;
  String get location => representative.location;
  String get category => representative.category;
  int get postCount => posts.length;
  int get totalUpvotes => posts.fold(0, (sum, p) => sum + p.upvotes);
  int get totalComments => posts.fold(0, (sum, p) => sum + p.commentCount);
  double get lat => representative.lat;
  double get lng => representative.lng;

  List<String> get postIds => posts.map((p) => p.postId).toList();

  /// Groups a flat list of posts into place groups.
  /// Two posts are in the same group if any of these match:
  ///   1. Their normalized titles are identical (non-empty after stripping common words)
  ///   2. Their location strings are identical (non-empty)
  ///   3. Both have valid coordinates within 150 m of each other
  static List<PlaceGroup> groupPosts(List<PostModel> posts) {
    final groups = <String, List<PostModel>>{};

    for (final post in posts) {
      final key = _findOrCreateKey(post, groups);
      groups.putIfAbsent(key, () => []).add(post);
    }

    return groups.entries
        .map((e) => PlaceGroup(placeKey: e.key, posts: e.value))
        .toList()
      ..sort((a, b) => b.totalUpvotes.compareTo(a.totalUpvotes));
  }

  static String _normalizeTitle(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r"['''\-_&]"), ' ')
        .replaceAll(
          RegExp(
            r'\b(restaurant|restaurants|cafe|cafes|café|cafés|bar|bars|pub|pubs|'
            r'shop|shops|store|stores|park|parks|lounge|grills?|bistro|eatery|eateries)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _hasCoords(PostModel p) => p.lat != 0.0 && p.lng != 0.0;

  static double _distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _findOrCreateKey(
      PostModel post, Map<String, List<PostModel>> existing) {
    final normTitle = _normalizeTitle(post.title);
    final hasCoords = _hasCoords(post);

    for (final entry in existing.entries) {
      final rep = entry.value.first;

      if (normTitle.isNotEmpty && _normalizeTitle(rep.title) == normTitle) {
        return entry.key;
      }
      if (post.location.isNotEmpty &&
          post.location.trim().toLowerCase() ==
              rep.location.trim().toLowerCase()) {
        return entry.key;
      }
      if (hasCoords && _hasCoords(rep)) {
        if (_distanceMeters(post.lat, post.lng, rep.lat, rep.lng) < 150) {
          return entry.key;
        }
      }
    }

    return normTitle.isNotEmpty ? normTitle : post.postId;
  }
}
