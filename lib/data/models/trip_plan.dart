/// One stop in an AI- (or locally-) generated itinerary.
class TripStop {
  final String postId;
  final int stayMinutes;
  final String note; // e.g. "~12 min walk from the previous stop"

  const TripStop({
    required this.postId,
    this.stayMinutes = 45,
    this.note = '',
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    final raw = json['stayMinutes'] ?? json['minutes'] ?? json['stay'];
    final mins = (raw is num)
        ? raw.toInt()
        : int.tryParse('${raw ?? ''}') ?? 45;
    return TripStop(
      postId: (json['id'] ?? json['postId'] ?? '').toString(),
      stayMinutes: mins.clamp(15, 240),
      note: (json['note'] ?? json['walk'] ?? json['travel'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'stayMinutes': stayMinutes,
        'note': note,
      };
}
