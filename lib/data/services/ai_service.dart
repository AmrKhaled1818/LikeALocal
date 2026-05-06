import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../../core/constants/app_config.dart';

class AIService {
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
        'You are the AI Assistant for LikeALocal. '
        'User preferences: budget=${prefs['budget'] ?? 'any'}, '
        'atmosphere=${prefs['atmosphere'] ?? 'any'}, '
        'favorite categories=$favCats.$locationText$placesText\n'
        'CRITICAL RULES:\n'
        '1. Be extremely concise. Do not talk a lot. Give short, direct answers.\n'
        '2. Always suggest exactly ONE specific good place based on the request.\n'
        '3. Clearly state the place name and location (e.g. "Place Name in City Name").';

    // Build message history — drop leading AI messages, keep last 10
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

    final body = jsonEncode({
      'model': AppConfig.aiModel,
      'messages': messages,
      'temperature': 0.3,
      'max_tokens': 300,
    });

    final url = Uri.parse('${AppConfig.apiBaseUrl}/chat/completions');

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .post(url, headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppConfig.openRouterKey}',
              'HTTP-Referer': 'https://likealocal.app',
              'X-Title': 'LikeALocal',
            }, body: body)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices == null || choices.isEmpty) {
            return 'Sorry, I couldn\'t generate a response. Please try again.';
          }
          return choices[0]['message']['content'] as String? ??
              'Sorry, I couldn\'t generate a response. Please try again.';
        }

        debugPrint(
            'OpenRouter attempt $attempt: HTTP ${response.statusCode} — '
            '${response.body.substring(0, response.body.length.clamp(0, 300))}');

        String errMsg = 'Error ${response.statusCode}';
        try {
          final errData = jsonDecode(response.body);
          errMsg = errData['error']['message'] ?? errMsg;
        } catch (_) {}

        if (response.statusCode == 429 &&
            errMsg.toLowerCase().contains('quota')) {
          return 'AI quota limit reached for today. Please try again tomorrow.';
        }

        if ((response.statusCode == 503 || response.statusCode == 429) &&
            attempt < 3) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }

        return 'AI unavailable right now. Please try again.';
      } catch (e) {
        debugPrint('OpenRouter attempt $attempt exception: $e');
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
