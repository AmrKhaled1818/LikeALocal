import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_config.dart';

/// Result of an OpenRouter vision call.
///
/// `description` is the model output (may be empty on failure).
/// `rateLimited` is true if the request was rejected with HTTP 429 — the UI
/// can use this to surface a friendlier "AI description unavailable" toast.
class VisionResult {
  final String description;
  final bool rateLimited;
  final String? errorMessage;

  const VisionResult({
    required this.description,
    this.rateLimited = false,
    this.errorMessage,
  });

  bool get isEmpty => description.isEmpty;
  bool get isSuccess => description.isNotEmpty;
}

/// Calls OpenRouter's free vision model to generate a 1–2 sentence
/// description for a post image.
///
/// Never throws — returns an empty [VisionResult] on failure so callers can
/// silently fall back to manual entry without breaking post creation.
class VisionService {
  static const _timeout = Duration(seconds: 25);

  /// Generates a short description for [imageFile].
  ///
  /// Optional [placeName] and [caption] are folded into the prompt so the
  /// model has extra context beyond the pixels (e.g. the venue name and
  /// what the user already typed). Returns `VisionResult(description: '')`
  /// if the API key is missing, the call fails, or the response is malformed.
  static Future<VisionResult> generateImageDescription(
    XFile imageFile, {
    String placeName = '',
    String caption = '',
  }) async {
    if (!AppConfig.hasVisionKey) {
      return const VisionResult(
        description: '',
        errorMessage: 'OPENROUTER_API_KEY is not set',
      );
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _detectMimeType(imageFile);
      final dataUri = 'data:$mimeType;base64,$base64Image';
      final prompt = _buildPrompt(
          placeName: placeName.trim(), caption: caption.trim());

      final response = await http
          .post(
            Uri.parse('${AppConfig.openRouterBaseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://likealocal.app',
              'X-Title': 'LikeALocal',
            },
            body: jsonEncode({
              'model': AppConfig.openRouterVisionModel,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {'type': 'text', 'text': prompt},
                    {
                      'type': 'image_url',
                      'image_url': {'url': dataUri},
                    },
                  ],
                },
              ],
              'max_tokens': 120,
              'temperature': 0.7,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 429) {
        return const VisionResult(
          description: '',
          rateLimited: true,
          errorMessage: 'rate limited',
        );
      }
      if (response.statusCode != 200) {
        return VisionResult(
          description: '',
          errorMessage: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return const VisionResult(
          description: '',
          errorMessage: 'no choices in response',
        );
      }
      final message = (choices.first as Map)['message'] as Map?;
      final raw = message?['content'];
      final text = raw is String
          ? raw.trim()
          : (raw is List
              ? raw
                  .whereType<Map>()
                  .map((p) => (p['text'] ?? '').toString())
                  .join(' ')
                  .trim()
              : '');

      return VisionResult(description: _cleanup(text));
    } catch (e, st) {
      debugPrint('VisionService error: $e\n$st');
      return VisionResult(description: '', errorMessage: e.toString());
    }
  }

  /// Builds the user-facing prompt. When the caller has a place name or a
  /// caption draft, we surface them so the model can incorporate that
  /// context (without making them up if the image disagrees).
  static String _buildPrompt({
    required String placeName,
    required String caption,
  }) {
    final buf = StringBuffer(
      'Write a 1-2 sentence description of this place for a social post. '
      'Focus on what makes it special or interesting. Be concise and engaging. '
      'Return only the description with no preamble or quotes.',
    );
    if (placeName.isNotEmpty) {
      buf.write('\n\nThe place is called: "$placeName".');
    }
    if (caption.isNotEmpty) {
      buf.write(
          '\n\nThe user already wrote this caption — use it as context and stay consistent with its tone:\n"$caption"');
    }
    if (placeName.isNotEmpty || caption.isNotEmpty) {
      buf.write(
          '\n\nIf the image and the context disagree, trust the image.');
    }
    return buf.toString();
  }

  /// Best-effort mime-type detection from the file extension.
  /// OpenRouter is lenient about this, so `image/jpeg` is a fine default.
  static String _detectMimeType(XFile file) {
    final path = file.path.toLowerCase();
    final name = file.name.toLowerCase();
    final target = path.isNotEmpty ? path : name;
    if (target.endsWith('.png')) return 'image/png';
    if (target.endsWith('.gif')) return 'image/gif';
    if (target.endsWith('.webp')) return 'image/webp';
    if (target.endsWith('.heic') || target.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }

  /// Strips markdown wrappers / quotes / leading "Description:" the model
  /// sometimes prefixes despite the instruction.
  static String _cleanup(String s) {
    var out = s.trim();
    if (out.startsWith('"') && out.endsWith('"') && out.length >= 2) {
      out = out.substring(1, out.length - 1).trim();
    }
    final lower = out.toLowerCase();
    const prefixes = ['description:', 'caption:', 'image:'];
    for (final p in prefixes) {
      if (lower.startsWith(p)) {
        out = out.substring(p.length).trim();
        break;
      }
    }
    return out;
  }

  /// Convenience wrapper for callers that hold a [File] rather than [XFile].
  static Future<VisionResult> generateFromFile(File file) {
    return generateImageDescription(XFile(file.path));
  }
}
