import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:like_a_local/core/utils/crowd_utils.dart';
import 'package:like_a_local/data/models/post_model.dart';

PostModel _post({
  String category = 'Restaurant',
  Map<int, int>? checkins,
  Timestamp? lastCheckinAt,
  String bestTime = '',
}) =>
    PostModel(
      postId: 'p',
      userId: 'u',
      username: 'u',
      title: 'Place',
      category: category,
      checkinsByHour: checkins,
      lastCheckinAt: lastCheckinAt,
      bestTime: bestTime,
    );

void main() {
  group('crowd_utils', () {
    test('formatHour handles noon and midnight', () {
      expect(formatHour(0), '12 AM');
      expect(formatHour(12), '12 PM');
      expect(formatHour(9), '9 AM');
      expect(formatHour(18), '6 PM');
    });

    test('isBusyNow is true only for a recent check-in', () {
      final recent = _post(lastCheckinAt: Timestamp.now());
      final old = _post(
          lastCheckinAt: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(hours: 5))));
      expect(isBusyNow(recent), isTrue);
      expect(isBusyNow(old), isFalse);
      expect(isBusyNow(_post()), isFalse);
    });

    test('peakHour needs a minimum sample', () {
      expect(peakHour(_post(checkins: {18: 2})), isNull);
      expect(peakHour(_post(checkins: {18: 3, 19: 1})), 18);
      expect(peakHour(_post(checkins: {9: 5, 18: 10, 20: 2})), 18);
    });

    test('crowdInfo prefers live → peak → AI hint → heuristic', () {
      expect(crowdInfo(_post(lastCheckinAt: Timestamp.now())).isLive, isTrue);

      final peaky = crowdInfo(_post(checkins: {19: 4}));
      expect(peaky.isLive, isFalse);
      expect(peaky.label, contains('7 PM'));

      final aiHint = crowdInfo(_post(bestTime: 'Golden hour ~6 PM'));
      expect(aiHint.label, 'Golden hour ~6 PM');

      final heuristic = crowdInfo(_post(category: 'Bar'));
      expect(heuristic.label.toLowerCase(), contains('9 pm'));
    });
  });
}
