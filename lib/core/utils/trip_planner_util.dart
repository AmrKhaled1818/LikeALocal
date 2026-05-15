import 'dart:math' as math;
import '../../data/models/post_model.dart';
import '../../data/models/trip_plan.dart';
import 'vibe_score.dart';

/// Great-circle distance in metres.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;

bool hasCoords(PostModel p) => p.lat != 0.0 || p.lng != 0.0;

int stayMinutesFor(String category) {
  switch (category.toLowerCase()) {
    case 'restaurant':
      return 75;
    case 'café':
    case 'cafe':
      return 45;
    case 'bar':
      return 60;
    case 'park':
      return 60;
    case 'viewpoint':
      return 30;
    case 'shop':
      return 40;
    case 'mall':
      return 90;
    case 'cultural':
      return 60;
    default:
      return 45;
  }
}

/// ~5 km/h walking; switches wording to "ride" for longer hops.
String travelNote(double meters, {bool fromStart = false}) {
  final from = fromStart ? 'from your start' : 'from the last stop';
  if (meters < 1200) {
    final mins = math.max(1, (meters / 83).round()); // ~5 km/h
    return '~$mins min walk $from';
  }
  final km = meters / 1000;
  final mins = math.max(3, (km / 0.4).round()); // ~24 km/h city ride
  return '~$mins min ride $from (${km.toStringAsFixed(1)} km)';
}

int travelMinutes(double meters) {
  if (meters < 1200) return math.max(1, (meters / 83).round());
  return math.max(3, ((meters / 1000) / 0.4).round());
}

/// Greedy nearest-neighbour itinerary used when the AI is unavailable or
/// returns nothing usable. Prefers places whose category matches [mood] or
/// any explicitly [preferredCategories].
List<TripStop> greedyItinerary(
  List<PostModel> candidates, {
  double? startLat,
  double? startLng,
  required int minutesAvailable,
  String mood = '',
  List<String> preferredCategories = const [],
}) {
  final pool = candidates.where(hasCoords).toList();
  if (pool.isEmpty) return const [];

  final moodCats = (kMoodCategories[mood] ?? const [])
      .map((e) => e.toLowerCase())
      .toSet();
  final allPreferred = {
    ...moodCats,
    ...preferredCategories.map((e) => e.toLowerCase()),
  };

  pool.sort((a, b) {
    final am = allPreferred.contains(a.category.toLowerCase()) ? 1 : 0;
    final bm = allPreferred.contains(b.category.toLowerCase()) ? 1 : 0;
    if (am != bm) return bm - am;
    return b.upvotes.compareTo(a.upvotes);
  });

  var curLat = startLat ?? pool.first.lat;
  var curLng = startLng ?? pool.first.lng;
  final usingStart = startLat != null && startLng != null;

  final remaining = List<PostModel>.from(pool);
  final stops = <TripStop>[];
  var spent = 0;
  var first = true;

  while (remaining.isNotEmpty && stops.length < 6) {
    remaining.sort((a, b) {
      final da = haversineMeters(curLat, curLng, a.lat, a.lng) *
          (allPreferred.contains(a.category.toLowerCase()) ? 0.7 : 1.0);
      final db = haversineMeters(curLat, curLng, b.lat, b.lng) *
          (allPreferred.contains(b.category.toLowerCase()) ? 0.7 : 1.0);
      return da.compareTo(db);
    });
    final next = remaining.removeAt(0);
    final meters = haversineMeters(curLat, curLng, next.lat, next.lng);
    final travel = (first && usingStart) || stops.isNotEmpty ? travelMinutes(meters) : 0;
    final stay = stayMinutesFor(next.category);
    if (spent + travel + stay > minutesAvailable && stops.isNotEmpty) break;

    stops.add(TripStop(
      postId: next.postId,
      stayMinutes: stay,
      note: (first && !usingStart)
          ? 'Start here'
          : travelNote(meters, fromStart: first && usingStart),
    ));
    spent += travel + stay;
    curLat = next.lat;
    curLng = next.lng;
    first = false;
  }
  return stops;
}

/// Sum of stay + estimated travel for an ordered list of resolved posts.
int estimateTotalMinutes(
  List<TripStop> stops,
  Map<String, PostModel> byId, {
  double? startLat,
  double? startLng,
}) {
  var total = 0;
  double? curLat = startLat;
  double? curLng = startLng;
  for (final s in stops) {
    final p = byId[s.postId];
    if (p == null) continue;
    if (curLat != null && curLng != null && hasCoords(p)) {
      total += travelMinutes(haversineMeters(curLat, curLng, p.lat, p.lng));
    }
    total += s.stayMinutes;
    if (hasCoords(p)) {
      curLat = p.lat;
      curLng = p.lng;
    }
  }
  return total;
}
