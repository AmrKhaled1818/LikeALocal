import 'package:flutter_test/flutter_test.dart';
import 'package:like_a_local/core/utils/vibe_score.dart';
import 'package:like_a_local/data/models/post_model.dart';

PostModel _post({
  String category = 'Restaurant',
  String title = 'Some Place',
  String description = '',
  String localTips = '',
  int upvotes = 0,
}) =>
    PostModel(
      postId: 'p',
      userId: 'u',
      username: 'u',
      title: title,
      description: description,
      localTips: localTips,
      category: category,
      upvotes: upvotes,
    );

void main() {
  group('VibeScore', () {
    test('stays within 0-100 and has a non-zero baseline', () {
      final s = VibeScore.forPost(_post(), null);
      expect(s, inInclusiveRange(0, 100));
      expect(s, greaterThan(0));
    });

    test('favourite category boosts the score', () {
      final post = _post(category: 'Café');
      final withFav = VibeScore.forPost(post, {'favCategories': ['Café']});
      final without = VibeScore.forPost(post, {'favCategories': ['Bar']});
      expect(withFav, greaterThan(without));
    });

    test('café / cafe spellings are treated as equal', () {
      final post = _post(category: 'Café');
      final a = VibeScore.forPost(post, {'favCategories': ['cafe']});
      final b = VibeScore.forPost(post, {'favCategories': ['Café']});
      expect(a, b);
    });

    test('mood keywords nudge the score up', () {
      final plain = _post(description: 'a place');
      final cozy = _post(description: 'a cozy quiet relaxing place');
      expect(
        VibeScore.forPost(cozy, null, mood: 'chill'),
        greaterThan(VibeScore.forPost(plain, null, mood: 'chill')),
      );
    });

    test('popularity raises the score but is capped', () {
      final low = VibeScore.forPost(_post(upvotes: 1), null);
      final high = VibeScore.forPost(_post(upvotes: 9999), null);
      expect(high, greaterThan(low));
      expect(high, lessThanOrEqualTo(100));
    });

    test('label buckets are ordered', () {
      expect(VibeScore.label(90), 'Top match');
      expect(VibeScore.label(72), 'Great fit');
      expect(VibeScore.label(58), 'Good fit');
      expect(VibeScore.label(40), 'Worth a look');
    });
  });
}
