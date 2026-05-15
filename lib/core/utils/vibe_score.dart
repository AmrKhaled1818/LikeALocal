import '../../data/models/post_model.dart';

/// Moods the home feed can be tuned to. Used by onboarding, the top bar, and
/// [PostsProvider]'s ranking.
const kMoods = <String>['chill', 'adventurous', 'hungry', 'cultural'];

const kMoodLabels = <String, String>{
  '': 'Any vibe',
  'chill': 'Chill',
  'adventurous': 'Adventurous',
  'hungry': 'Hungry',
  'cultural': 'Cultural',
};

/// Categories a given mood favours (lower-cased on use).
const kMoodCategories = <String, List<String>>{
  'chill': ['Café', 'Park', 'Viewpoint'],
  'adventurous': ['Viewpoint', 'Park'],
  'hungry': ['Restaurant', 'Café'],
  'cultural': ['Cultural'],
};

const _moodKeywords = <String, List<String>>{
  'chill': ['cozy', 'quiet', 'calm', 'relax', 'peaceful', 'chill', 'serene'],
  'adventurous': [
    'hike', 'view', 'adventure', 'rooftop', 'hidden', 'explore', 'outdoor', 'trail'
  ],
  'hungry': [
    'food', 'dish', 'eat', 'tasty', 'delicious', 'meal', 'cuisine', 'brunch', 'dinner'
  ],
  'cultural': [
    'history', 'art', 'cultural', 'heritage', 'gallery', 'historic', 'traditional', 'museum', 'exhibit'
  ],
};

const _atmosphereKeywords = <String, List<String>>{
  'cozy': ['cozy', 'quiet', 'intimate', 'warm', 'calm', 'snug'],
  'trendy': ['trendy', 'hip', 'modern', 'buzzing', 'lively', 'vibrant', 'stylish'],
  'outdoor': ['outdoor', 'park', 'garden', 'open air', 'rooftop', 'terrace', 'nature'],
  'historic': ['historic', 'old', 'heritage', 'classic', 'traditional', 'cultural'],
};

const _lowBudgetWords = [
  'cheap', 'affordable', 'budget', 'street food', 'local joint', 'inexpensive', 'value'
];
const _highBudgetWords = [
  'fine dining', 'upscale', 'luxury', 'rooftop', 'premium', 'fancy', 'high-end', 'exclusive'
];

bool _catEquals(String a, String b) {
  final x = a.toLowerCase();
  final y = b.toLowerCase();
  if (x == y) return true;
  return {x, y}.containsAll({'café', 'cafe'});
}

/// Computes a 0–100 "vibe match" percentage for [post] against the user's saved
/// [prefs] (`favCategories`, `budget`, `atmosphere`) plus the live [mood].
/// Always returns at least a small baseline so a card never reads as a hard 0%.
class VibeScore {
  static int forPost(PostModel post, Map<String, dynamic>? prefs,
      {String mood = ''}) {
    final p = prefs ?? const <String, dynamic>{};
    int score = 35; // baseline

    final favCats = ((p['favCategories'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    if (favCats.isNotEmpty) {
      if (favCats.any((c) => _catEquals(c, post.category))) score += 30;
    } else {
      score += 12; // no prefs yet → mild neutral bump
    }

    final haystack = ('${post.title} ${post.description} ${post.localTips} '
            '${post.recommendedDishes.join(' ')}')
        .toLowerCase();

    final atm = (p['atmosphere'] ?? '').toString().toLowerCase();
    if (atm.isNotEmpty && (_atmosphereKeywords[atm] ?? const []).any(haystack.contains)) {
      score += 15;
    }

    final budget = (p['budget'] ?? '').toString().toLowerCase();
    if (budget == 'low' && _lowBudgetWords.any(haystack.contains)) score += 8;
    if (budget == 'high' && _highBudgetWords.any(haystack.contains)) score += 8;
    if (budget == 'mid') score += 4;

    if (mood.isNotEmpty) {
      final moodCats = kMoodCategories[mood] ?? const [];
      if (moodCats.any((c) => _catEquals(c, post.category))) score += 8;
      if ((_moodKeywords[mood] ?? const []).any(haystack.contains)) score += 6;
    }

    score += post.upvotes.clamp(0, 12);

    return score.clamp(0, 100);
  }

  /// Bucketed label for a score, e.g. "Top match" / "Great fit".
  static String label(int score) {
    if (score >= 85) return 'Top match';
    if (score >= 70) return 'Great fit';
    if (score >= 55) return 'Good fit';
    return 'Worth a look';
  }
}
