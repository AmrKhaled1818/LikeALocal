import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../models/post_model.dart';
import '../models/trip_plan.dart';
import '../models/user_model.dart';
import '../../core/constants/app_config.dart';

/// Raised when a Groq API request cannot be fulfilled. [message] is always
/// safe to display to the user (never contains the API key).
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

/// Metadata captured from the most recent Groq call (any [AIService] method).
/// Useful for diagnostics and the live migration test — never logged with the key.
class AiCallStats {
  final int statusCode;
  final String model;
  final bool usedFallback;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  /// Server-side total time from Groq's `usage.total_time` (seconds → ms).
  final int? groqTotalTimeMs;

  /// Server-side queue time from Groq's `usage.queue_time` (seconds → ms).
  final int? groqQueueTimeMs;

  /// Subset of response headers: `x-ratelimit-*` and `retry-after`, keyed
  /// lower-case.
  final Map<String, String> rateLimitHeaders;

  const AiCallStats({
    required this.statusCode,
    required this.model,
    required this.usedFallback,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.groqTotalTimeMs,
    this.groqQueueTimeMs,
    this.rateLimitHeaders = const {},
  });
}

class AIService {
  /// Stats from the last completed Groq call. Read after any call for diagnostics.
  static AiCallStats? lastStats;

  static Uri get _endpoint =>
      Uri.parse('${AppConfig.groqBaseUrl}/chat/completions');

  static const _rateLimitHeaderKeys = <String>{
    'x-ratelimit-limit-requests',
    'x-ratelimit-remaining-requests',
    'x-ratelimit-reset-requests',
    'x-ratelimit-limit-tokens',
    'x-ratelimit-remaining-tokens',
    'x-ratelimit-reset-tokens',
    'retry-after',
  };

  // ── Public methods ───────────────────────────────────────────────────────

  /// Conversational discovery assistant. PRIMARY model.
  /// Returns the assistant reply as a displayable string; on failure it returns
  /// a friendly error string so the chat UI can render it like any other reply.
  Future<String> getAIResponse(
      List<MessageModel> history, UserModel currentUser,
      {double? lat, double? lng, String? availablePlaces}) async {
    final prefs = currentUser.preferences;
    final favCats = (prefs['favCategories'] as List?)?.join(', ') ?? '';
    final locationText = (lat != null && lng != null)
        ? ' The user is currently located at latitude=$lat, longitude=$lng.'
        : '';
    final placesText = (availablePlaces != null && availablePlaces.isNotEmpty)
        ? ' Here are the places available in our app (always try to recommend from these if possible): $availablePlaces.'
        : '';

    final systemText =
        'You are the AI Discovery Assistant for LikeALocal, a hidden-gems social app. '
        'You help users find hidden gems and local spots.\n'
        'User preferences — budget: ${prefs['budget'] ?? 'any'}, '
        'atmosphere: ${prefs['atmosphere'] ?? 'any'}, '
        'favorite categories: ${favCats.isNotEmpty ? favCats : 'any'}.$locationText\n'
        '${placesText.isNotEmpty ? 'Places available in the app: $placesText\n' : ''}'
        'HOW TO BEHAVE:\n'
        '- For greetings (hi, hello, hey, thanks, etc.): respond warmly in one sentence and ask what kind of place they are looking for.\n'
        '- For recommendation requests: suggest 2-3 places. Format each as: **Place Name** — Location: one-line reason.\n'
        '- For vague requests: ask ONE short clarifying question (area, occasion, or type of place).\n'
        '- For non-recommendation questions: answer helpfully and concisely.\n'
        '- Prefer places from the app list. Only suggest outside places if nothing fits.\n'
        '- Keep responses under 6 lines. No bullet points for greetings. NEVER narrate your reasoning.';

    // Build message history — drop leading AI messages, keep last 10.
    var recent = history.takeLast(10);
    while (recent.isNotEmpty && recent.first.senderId == 'ai') {
      recent = recent.sublist(1);
    }
    if (recent.isEmpty) {
      return 'Ask me anything about local spots and hidden gems!';
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemText},
      ...recent.map((m) => {
            'role': m.senderId == 'ai' ? 'assistant' : 'user',
            'content': m.text,
          }),
    ];

    try {
      return await _complete(
        messages: messages,
        model: AppConfig.groqPrimaryModel,
        temperature: 0.3,
        maxTokens: 300,
      );
    } on AiException catch (e) {
      return e.message;
    }
  }

  /// Two-sentence friendly summary of a hidden gem. PRIMARY model.
  /// Returns '' on failure so callers can skip silently.
  Future<String> generatePostSummary({
    required String title,
    required String category,
    required String description,
    required String localTips,
  }) async {
    final prompt =
        'Write exactly 2 friendly sentences summarising this hidden gem for the LikeALocal app. '
        'Be warm, specific, and helpful. Do NOT use bullet points or markdown.\n\n'
        'Place: $title ($category)\n'
        'Description: $description\n'
        '${localTips.isNotEmpty ? 'Local Tips: $localTips' : ''}';
    try {
      return await _complete(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        model: AppConfig.groqPrimaryModel,
        temperature: 0.5,
        maxTokens: 120,
      );
    } on AiException {
      return '';
    }
  }

  /// Short "best time to visit" phrase for the crowd indicator, e.g.
  /// "Golden hour around 6 PM" or "Quietest before noon". <= 6 words, no markdown.
  /// Trivial generation — routed to the FALLBACK model. Returns '' on failure.
  Future<String> generateBestTimeHint({
    required String title,
    required String category,
    required String description,
  }) async {
    final prompt =
        'For the LikeALocal app, give the single best time to visit this place '
        'as a short phrase of at most 6 words (e.g. "Golden hour around 6 PM", '
        '"Quietest before noon", "Lively after 9 PM"). No markdown, no extra text.\n\n'
        'Place: $title ($category)\n'
        'Description: $description';
    try {
      final txt = await _complete(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        model: AppConfig.groqFallbackModel,
        temperature: 0.4,
        maxTokens: 24,
        timeout: const Duration(seconds: 30),
      );
      // Keep it short even if the model rambles.
      return txt.replaceAll('"', '').replaceAll('*', '').split('\n').first.trim();
    } on AiException {
      return '';
    }
  }

  /// Asks the AI to build an ordered itinerary from [candidates] given the
  /// user's time budget, mood, and optional start point. PRIMARY model.
  /// Returns an empty list on any failure (callers should fall back to greedyItinerary).
  Future<List<TripStop>> planTrip({
    required List<PostModel> candidates,
    required int minutesAvailable,
    String mood = '',
    String budget = '',
    double? startLat,
    double? startLng,
    List<String> categories = const [],
    String groupSize = '',
    String transport = '',
    String timeOfDay = '',
  }) async {
    if (candidates.isEmpty) return const [];

    final list = candidates.take(30).map((p) {
      return '{"id":"${p.postId}","title":"${_clean(p.title)}",'
          '"category":"${p.category}","area":"${_clean(p.location)}",'
          '"lat":${p.lat.toStringAsFixed(5)},"lng":${p.lng.toStringAsFixed(5)},'
          '"upvotes":${p.upvotes}}';
    }).join(',');

    final startText = (startLat != null && startLng != null)
        ? 'The user starts at lat=${startLat.toStringAsFixed(5)}, lng=${startLng.toStringAsFixed(5)}.'
        : 'The user has no fixed start point — begin at whichever place makes the best route.';

    final constraints = [
      'time available: $minutesAvailable minutes',
      if (mood.isNotEmpty) 'mood: $mood',
      if (budget.isNotEmpty) 'budget: $budget',
      if (categories.isNotEmpty) 'preferred place types: ${categories.join(', ')}',
      if (groupSize.isNotEmpty) 'group: $groupSize',
      if (transport.isNotEmpty) 'transport preference: $transport',
      if (timeOfDay.isNotEmpty) 'time of day: $timeOfDay',
    ].join('; ');

    final prompt =
        'You are a local trip planner for the LikeALocal app. Build ONE itinerary.\n'
        'Available places (JSON): [$list]\n'
        '$startText\n'
        'User preferences: $constraints.\n'
        'Rules:\n'
        '- Pick 3 to 5 places ONLY from the list above (use the "id" field)\n'
        '- Order them as a sensible walking/short-ride route (nearby places consecutive)\n'
        '- If preferred place types are specified, prioritise those categories\n'
        '- Match the time of day: cafés/parks for morning, bars/viewpoints for evening, restaurants for any time\n'
        '- For couples/groups prefer atmospheric or social venues; for solo prefer easier solo-friendly spots\n'
        '- If transport is "walking only", keep stops geographically very close\n'
        '- Give a realistic stay in minutes and a one-line travel note from the previous stop\n'
        'Respond with ONLY a JSON array, no markdown, no prose:\n'
        '[{"id":"<place id>","stayMinutes":45,"note":"~10 min walk from start"}, ...]';

    try {
      final raw = await _complete(
        messages: [
          {'role': 'user', 'content': prompt},
        ],
        model: AppConfig.groqPrimaryModel,
        temperature: 0.4,
        maxTokens: 500,
      );
      return _parseTripJson(raw);
    } on AiException {
      return const [];
    }
  }

  /// Text-based trip itinerary for [city] when no local PostModel candidates
  /// are available (e.g. diagnostics, tests). PRIMARY model.
  /// Throws [AiException] on failure.
  Future<String> planCityTrip({
    required String city,
    required String duration,
    String mood = '',
  }) async {
    final moodText = mood.isNotEmpty ? ' with a $mood vibe' : '';
    final prompt =
        'Plan a $duration trip in $city$moodText for a traveller using LikeALocal. '
        'Give 3-5 stops in visiting order. For each stop write one line: '
        '**Name** — neighbourhood: one-sentence why and a local tip. '
        'No long intro, no closing paragraph, plain markdown only.';
    return _complete(
      messages: [
        {
          'role': 'system',
          'content':
              'You are a local guide for LikeALocal. Be concrete, concise, and practical.',
        },
        {'role': 'user', 'content': prompt},
      ],
      model: AppConfig.groqPrimaryModel,
      temperature: 0.4,
      maxTokens: 400,
    );
  }

  /// Parses a free-text vibe-search query into structured filters.
  /// Returns {category: String, atmosphere: String, keywords: List of String}.
  /// FALLBACK model with JSON mode. Throws [AiException] on failure.
  Future<Map<String, dynamic>> parseVibeQuery(String query) async {
    const sys =
        'You convert a short place-search phrase into JSON for the LikeALocal app. '
        'Respond with ONLY a JSON object of the form '
        '{"category": "", "atmosphere": "", "keywords": []}. '
        'category must be one of: Restaurant, Bar, Café, Park, Viewpoint, Shop, or "" if unclear. '
        'atmosphere is one short word like cozy, trendy, outdoor, historic, lively, quiet, or "". '
        'keywords is an array of 2-5 lowercase single words distilled from the phrase. No prose.';
    final raw = await _complete(
      messages: [
        {'role': 'system', 'content': sys},
        {'role': 'user', 'content': query},
      ],
      model: AppConfig.groqFallbackModel,
      temperature: 0.0,
      maxTokens: 120,
      jsonMode: true,
    );
    final parsed = _decodeJsonObject(raw);
    return <String, dynamic>{
      'category': (parsed['category'] ?? '').toString(),
      'atmosphere': (parsed['atmosphere'] ?? '').toString(),
      'keywords': ((parsed['keywords'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    };
  }

  /// Generates 4-8 discovery tags for a place. FALLBACK model with JSON mode.
  /// Throws [AiException] on failure.
  Future<List<String>> generateTags({
    required String title,
    required String category,
    String description = '',
  }) async {
    const sys =
        'You generate discovery tags for places in the LikeALocal app. '
        'Respond with ONLY a JSON object {"tags": []} where tags is an array of '
        '4-8 lowercase tags (1-2 words each), no "#", no duplicates, no prose.';
    final raw = await _complete(
      messages: [
        {'role': 'system', 'content': sys},
        {
          'role': 'user',
          'content': 'Place: $title ($category)'
              '${description.isNotEmpty ? '\nDescription: $description' : ''}',
        },
      ],
      model: AppConfig.groqFallbackModel,
      temperature: 0.2,
      maxTokens: 100,
      jsonMode: true,
    );
    final parsed = _decodeJsonObject(raw);
    return ((parsed['tags'] as List?) ?? const [])
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  /// One-line insider tip about visiting a place or city. PRIMARY model.
  /// Throws [AiException] on failure.
  Future<String> generateLocalTip(String place) async {
    final prompt =
        'Give one genuinely useful local insider tip for visiting $place. '
        'One or two sentences, friendly, specific, no markdown, no preamble.';
    return (await _complete(
      messages: [
        {'role': 'user', 'content': prompt},
      ],
      model: AppConfig.groqPrimaryModel,
      temperature: 0.5,
      maxTokens: 100,
    ))
        .trim();
  }

  // ── Internals ────────────────────────────────────────────────────────────

  /// Core Groq request. Uses [model]; on HTTP 429 from a non-fallback model
  /// it retries ONCE on [AppConfig.groqFallbackModel] (logged). Backs off on
  /// 5xx. Populates [lastStats]. Throws [AiException] — callers decide how to
  /// surface errors.
  Future<String> _complete({
    required List<Map<String, String>> messages,
    required String model,
    double temperature = 0.3,
    int maxTokens = 300,
    bool jsonMode = false,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (AppConfig.groqApiKey.isEmpty) {
      throw const AiException(
          'AI is not configured. Run with --dart-define=GROQ_API_KEY=gsk_your_key');
    }

    var activeModel = model;
    var usedFallback = false;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final payload = <String, dynamic>{
          'model': activeModel,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
          if (jsonMode) 'response_format': {'type': 'json_object'},
        };

        final response = await http
            .post(
              _endpoint,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${AppConfig.groqApiKey}',
              },
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (response.statusCode == 401) {
          throw const AiException(
              'Invalid AI API Key. Please check your GROQ_API_KEY configuration.');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          _recordStats(response, data, activeModel, usedFallback);
          final choices = data['choices'] as List?;
          String? content;
          if (choices != null && choices.isNotEmpty) {
            final msg = (choices.first as Map)['message'];
            if (msg is Map) content = msg['content'] as String?;
          }
          if (content == null || content.trim().isEmpty) {
            throw const AiException(
                'Sorry, I could not generate a response. Please try again.');
          }
          return content;
        }

        _recordStats(response, null, activeModel, usedFallback);
        final detail = _errorDetail(response.body);
        debugPrint('Groq attempt $attempt ($activeModel): '
            'HTTP ${response.statusCode} — $detail');

        if (response.statusCode == 429) {
          final low = detail.toLowerCase();
          if (low.contains('quota') ||
              low.contains('daily') ||
              low.contains('per day')) {
            throw const AiException(
                'AI quota reached for today. Please try again tomorrow.');
          }
          // Rate-limited on the primary: fall back to the lighter model once.
          if (!usedFallback && activeModel != AppConfig.groqFallbackModel) {
            usedFallback = true;
            activeModel = AppConfig.groqFallbackModel;
            debugPrint('Groq 429 on $model — retrying once on fallback model '
                '${AppConfig.groqFallbackModel}');
            continue;
          }
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw const AiException(
              'AI is busy right now. Please try again in a moment.');
        }

        if (response.statusCode >= 500 && attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        throw AiException(
            'AI unavailable right now (HTTP ${response.statusCode}).');
      } on AiException {
        rethrow;
      } catch (e) {
        debugPrint('Groq attempt $attempt ($activeModel) exception: $e');
        if (attempt == 3) {
          throw const AiException(
              'Connection failed. Check your internet and try again.');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw const AiException(
        'Sorry, I am having trouble right now. Please try again.');
  }

  void _recordStats(http.Response res, Map<String, dynamic>? body,
      String activeModel, bool usedFallback) {
    final usage = body?['usage'];
    int? asMs(dynamic seconds) =>
        seconds is num ? (seconds * 1000).round() : null;
    int? asInt(dynamic v) => v is num ? v.toInt() : null;
    lastStats = AiCallStats(
      statusCode: res.statusCode,
      model: (body?['model'] as String?) ?? activeModel,
      usedFallback: usedFallback,
      promptTokens: usage is Map ? asInt(usage['prompt_tokens']) : null,
      completionTokens: usage is Map ? asInt(usage['completion_tokens']) : null,
      totalTokens: usage is Map ? asInt(usage['total_tokens']) : null,
      groqTotalTimeMs: usage is Map ? asMs(usage['total_time']) : null,
      groqQueueTimeMs: usage is Map ? asMs(usage['queue_time']) : null,
      rateLimitHeaders: {
        for (final e in res.headers.entries)
          if (_rateLimitHeaderKeys.contains(e.key.toLowerCase()))
            e.key.toLowerCase(): e.value,
      },
    );
  }

  String _errorDetail(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['error'] is Map && m['error']['message'] != null) {
        return m['error']['message'].toString();
      }
    } catch (_) {}
    return body.substring(0, body.length.clamp(0, 300));
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    var s = raw.trim();
    // Tolerate ```json fences in case the model adds them despite JSON mode.
    if (s.startsWith('```')) {
      s = s
          .replaceAll(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceAll(RegExp(r'```$'), '')
          .trim();
    }
    try {
      final v = jsonDecode(s);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    } catch (_) {}
    throw const AiException('AI returned malformed data. Please try again.');
  }

  static String _clean(String s) =>
      s.replaceAll('"', "'").replaceAll('\n', ' ').trim();

  static List<TripStop> _parseTripJson(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'```(json)?', caseSensitive: false), '');
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return const [];
    try {
      final arr = jsonDecode(text.substring(start, end + 1));
      if (arr is! List) return const [];
      return arr
          .whereType<Map>()
          .map((e) => TripStop.fromJson(e.cast<String, dynamic>()))
          .where((s) => s.postId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
