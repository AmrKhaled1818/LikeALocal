import 'package:flutter/material.dart';
import '../../data/models/post_model.dart';
import '../theme/app_colors.dart';

/// "6 PM", "12 PM" (noon), "12 AM" (midnight), "9 AM".
String formatHour(int h) {
  h = h % 24;
  final period = h < 12 ? 'AM' : 'PM';
  var display = h % 12;
  if (display == 0) display = 12;
  return '$display $period';
}

/// A place is "busy now" if it had a check-in in the last 2 hours.
bool isBusyNow(PostModel post) {
  final last = post.lastCheckinAt;
  if (last == null) return false;
  return DateTime.now().difference(last.toDate()).inMinutes < 120;
}

/// Hour with the most check-ins, but only once there's a meaningful sample.
int? peakHour(PostModel post) {
  final m = post.checkinsByHour;
  if (m.isEmpty) return null;
  final total = m.values.fold<int>(0, (a, b) => a + b);
  if (total < 3) return null;
  int? best;
  int bestCount = -1;
  m.forEach((h, c) {
    if (c > bestCount) {
      bestCount = c;
      best = h;
    }
  });
  return best;
}

/// Fallback "best time" phrase derived purely from the category.
String heuristicBestTime(String category) {
  switch (category.toLowerCase()) {
    case 'café':
    case 'cafe':
      return 'Best mid-morning';
    case 'restaurant':
      return 'Best around 8 PM';
    case 'bar':
      return 'Best after 9 PM';
    case 'park':
      return 'Best late afternoon';
    case 'viewpoint':
      return 'Best at golden hour (~6 PM)';
    case 'shop':
      return 'Best early afternoon';
    case 'mall':
      return 'Best in the evening';
    case 'cultural':
      return 'Best in the morning';
    default:
      return 'Best in the afternoon';
  }
}

class CrowdInfo {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLive; // true → "busy right now", false → a best-time hint

  const CrowdInfo(this.label, this.icon, this.color, this.isLive);
}

/// Picks the best available signal: live check-ins → check-in histogram peak →
/// AI-cached hint → category heuristic.
CrowdInfo crowdInfo(PostModel post) {
  if (isBusyNow(post)) {
    return const CrowdInfo(
        'Busy right now', Icons.local_fire_department, Color(0xFFEA580C), true);
  }
  final peak = peakHour(post);
  if (peak != null) {
    return CrowdInfo('Liveliest around ${formatHour(peak)}',
        Icons.insights_outlined, const Color(0xFF2563EB), false);
  }
  if (post.bestTime.trim().isNotEmpty) {
    return CrowdInfo(post.bestTime.trim(), Icons.schedule_outlined,
        const Color(0xFF0D9488), false);
  }
  return CrowdInfo(
      heuristicBestTime(post.category), Icons.schedule_outlined, kMutedFg, false);
}
