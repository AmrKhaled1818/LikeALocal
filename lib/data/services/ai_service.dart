import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../../core/constants/app_config.dart';

class AIService {
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<String> getAIResponse(
      List<MessageModel> history, UserModel currentUser,
      {double? lat, double? lng}) async {
    final prefs = currentUser.preferences;
    final favCats = (prefs['favCategories'] as List?)?.join(', ') ?? '';
    final locationText = (lat != null && lng != null)
        ? ' The user is currently located at latitude=$lat, longitude=$lng.'
        : '';

    final systemText =
        'You are the AI Discovery Assistant for LikeALocal, a local travel app. '
        'The user\'s preferences: budget=${prefs['budget'] ?? 'any'}, '
        'atmosphere=${prefs['atmosphere'] ?? 'any'}, '
        'favorite categories=$favCats.$locationText '
        'Help them discover hidden gems, restaurants, and local experiences. '
        'Be friendly, concise, and always suggest specific place names with their neighborhood or area.';

    // Build history — Gemini requires alternating user/model, starting with user
    var recent = history.takeLast(10);
    // Drop leading model messages so conversation always starts with user
    while (recent.isNotEmpty && recent.first.senderId == 'ai') {
      recent = recent.sublist(1);
    }

    final contents = recent.map((m) {
      final role = m.senderId == 'ai' ? 'model' : 'user';
      return {
        'role': role,
        'parts': [
          {'text': m.text}
        ],
      };
    }).toList();

    if (contents.isEmpty) {
      return 'Ask me anything about local spots and hidden gems!';
    }

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemText}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': 500,
        'temperature': 0.7,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    final url = Uri.parse(
        '$_baseUrl/${AppConfig.geminiModel}:generateContent'
        '?key=${AppConfig.googleApiKey}');

    // Retry up to 3 times for transient errors (503, 429)
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .post(url,
                headers: {'content-type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['candidates'][0]['content']['parts'][0]['text'] as String;
        }

        debugPrint(
            'Gemini attempt $attempt: HTTP ${response.statusCode} — ${response.body.substring(0, response.body.length.clamp(0, 200))}');

        // Retry on 503 (overloaded) or 429 (rate limit)
        if ((response.statusCode == 503 || response.statusCode == 429) &&
            attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }

        return 'Error ${response.statusCode} — please try again in a moment.';
      } catch (e) {
        debugPrint('Gemini attempt $attempt exception: $e');
        if (attempt == 3) {
          return 'Connection failed. Check your internet and try again.';
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }

    return 'Sorry, I\'m having trouble right now. Please try again.';
  }
}

extension _ListExtension<T> on List<T> {
  List<T> takeLast(int n) {
    if (length <= n) return this;
    return sublist(length - n);
  }
}
