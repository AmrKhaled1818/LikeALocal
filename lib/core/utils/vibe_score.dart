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
/// Deterministic — the same (post, prefs, mood) triple always returns the same
/// score. When a mood is selected, mood signals dominate so the feed visibly
/// reorders. When neither mood nor prefs are set, scoring leans on content
/// completeness + popularity so popular, well-written posts rank highest.
class VibeScore {
  static int forPost(PostModel post, Map<String, dynamic>? prefs,
      {String mood = ''}) {
    final p = prefs ?? const <String, dynamic>{};
    int score = 30; // baseline — every post starts here

    final haystack = ('${post.title} ${post.description} ${post.localTips} '
            '${post.recommendedDishes.join(' ')} ${post.category}')
        .toLowerCase();

    // ── Saved category preferences ────────────────────────────────────────
    final favCats = ((p['favCategories'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (favCats.isNotEmpty &&
        favCats.any((c) => _catEquals(c, post.category))) {
      score += 22;
    }

    // ── Atmosphere preference ─────────────────────────────────────────────
    final atm = (p['atmosphere'] ?? '').toString().toLowerCase();
    if (atm.isNotEmpty) {
      final kws = _atmosphereKeywords[atm] ?? const <String>[];
      final hits = kws.where(haystack.contains).length;
      if (hits > 0) score += (hits * 4).clamp(0, 12);
    }

    // ── Budget preference ─────────────────────────────────────────────────
    final budget = (p['budget'] ?? '').toString().toLowerCase();
    if (budget == 'low' && _lowBudgetWords.any(haystack.contains)) score += 6;
    if (budget == 'high' && _highBudgetWords.any(haystack.contains)) score += 6;

    // ── Mood (live selector) — DOMINANT signal when selected ──────────────
    // Big positive for matching category + per-keyword hits, and an explicit
    // penalty for off-mood category so the feed visibly reorders.
    if (mood.isNotEmpty) {
      final moodCats = kMoodCategories[mood] ?? const <String>[];
      final isMoodCat = moodCats.any((c) => _catEquals(c, post.category));
      if (isMoodCat) {
        score += 28;
      } else {
        score -= 12;
      }
      final moodKws = _moodKeywords[mood] ?? const <String>[];
      final kwHits = moodKws.where(haystack.contains).length;
      score += (kwHits * 5).clamp(0, 18);
    }

    // ── Content completeness — rewards effort, deterministic per post ─────
    if (post.description.length >= 60) score += 4;
    if (post.recommendedDishes.isNotEmpty) score += 3;
    if (post.localTips.isNotEmpty) score += 3;
    if (post.imageUrls.length > 1 || post.imageUrl.isNotEmpty) score += 2;

    // ── Popularity nudge — capped so it never dominates personalization ──
    score += post.upvotes.clamp(0, 10);

    // Floor at 15 so cards never read as a hard 0%; cap at 100.
    return score.clamp(15, 100);
  }

  /// Bucketed label for a score, e.g. "Top match" / "Great fit".
  static String label(int score) {
    if (score >= 85) return 'Top match';
    if (score >= 70) return 'Great fit';
    if (score >= 55) return 'Good fit';
    return 'Worth a look';
  }
}
