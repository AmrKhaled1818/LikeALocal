import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_config.dart';

/// Result of an OpenRouter vision call.
///
/// `description` is the model output (may be empty on failure).
/// `rateLimited` — request was rejected with HTTP 429.
/// `overloaded` — every attempt timed out or returned 5xx / 429, i.e. the
/// model is queued or unavailable rather than the code being broken. UI uses
/// this to show a friendlier "try again in a moment" message.
class VisionResult {
  final String description;
  final bool rateLimited;
  final bool overloaded;
  final String? errorMessage;

  const VisionResult({
    required this.description,
    this.rateLimited = false,
    this.overloaded = false,
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
  /// Per-attempt timeout. Using a reasoning model (Nemotron Omni) takes time
  /// (usually around 50s), so we need a generous timeout to ensure it doesn't
  /// get cut off prematurely.
  static const _attemptTimeout = Duration(seconds: 90);

  /// Generates a short description for [imageFile].
  ///
  /// Optional [placeName] and [caption] are folded into the prompt so the
  /// model has extra context beyond the pixels (e.g. the venue name and
  /// what the user already typed). Returns `VisionResult(description: '')`
  /// if the API key is missing, the call fails, or the response is malformed.
  ///
  /// Tries the primary model first; on timeout / 429 / 5xx / empty-response
  /// it retries on the configured fallback model, then falls back to a
  /// second attempt on the primary (handles transient queue blips). Total
  /// worst-case wall time is bounded by `_attemptTimeout × 3 + backoff`.
  static Future<VisionResult> generateImageDescription(
    XFile imageFile, {
    String placeName = '',
    String caption = '',
  }) async {
    if (!AppConfig.hasVisionKey) {
      return const VisionResult(
        description: '',
        errorMessage: 'GEMINI_API_KEY is not set',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _detectMimeType(imageFile);
    final prompt = _buildPrompt(
        placeName: placeName.trim(), caption: caption.trim());

    final model = AppConfig.geminiVisionModel;

    // We try the Gemini model up to 2 times to handle transient network issues.
    var sawTransient = false;
    String? lastError;

    for (var i = 0; i < 2; i++) {
      final attempt = await _callOnce(
        model: model,
        prompt: prompt,
        base64Image: base64Image,
        mimeType: mimeType,
      );

      if (attempt.isSuccess) return attempt;

      if (attempt.rateLimited) {
        sawTransient = true;
        lastError = attempt.errorMessage;
      } else if (attempt.overloaded) {
        sawTransient = true;
        lastError = attempt.errorMessage;
      } else {
        lastError = attempt.errorMessage;
        // Don't retry on hard errors (like bad API key)
        break;
      }

      // Small backoff before retry
      if (i == 0) await Future.delayed(const Duration(seconds: 1));
    }

    return VisionResult(
      description: '',
      overloaded: sawTransient,
      errorMessage: lastError,
    );
  }

  /// Single attempt against one model. Classifies failure as `overloaded`
  /// (timeout / 5xx), `rateLimited` (429), or a plain error so the caller
  /// can decide whether to retry on the fallback model.
  static Future<VisionResult> _callOnce({
    required String model,
    required String prompt,
    required String base64Image,
    required String mimeType,
  }) async {
    try {
      final apiKey = AppConfig.geminiApiKey;
      final response = await http
          .post(
            Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Image,
                      }
                    }
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.7,
                'maxOutputTokens': 600,
              }
            }),
          )
          .timeout(_attemptTimeout);

      if (response.statusCode == 429) {
        debugPrint('VisionService 429 on $model');
        return const VisionResult(
          description: '',
          rateLimited: true,
          overloaded: true,
          errorMessage: 'rate limited',
        );
      }
      if (response.statusCode >= 500) {
        debugPrint('VisionService ${response.statusCode} on $model');
        return VisionResult(
          description: '',
          overloaded: true,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
      if (response.statusCode != 200) {
        final body = response.body;
        debugPrint('VisionService HTTP ${response.statusCode} on $model: '
            '${body.length > 200 ? '${body.substring(0, 200)}...' : body}');
        return VisionResult(
          description: '',
          overloaded: false,
          errorMessage: 'HTTP ${response.statusCode}: $body',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return const VisionResult(
          description: '',
          overloaded: true,
          errorMessage: 'no candidates in response',
        );
      }
      
      final contentMap = candidates.first['content'] as Map?;
      final parts = contentMap?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return const VisionResult(
          description: '',
          overloaded: true,
          errorMessage: 'no parts in response',
        );
      }

      final raw = parts.first['text'];
      final text = raw is String ? raw.trim() : '';

      final cleaned = _cleanup(text);
      if (cleaned.isEmpty) {
        return const VisionResult(
          description: '',
          overloaded: true,
          errorMessage: 'empty model response',
        );
      }
      return VisionResult(description: cleaned);
    } on TimeoutException catch (e) {
      debugPrint('VisionService timeout on $model: $e');
      return const VisionResult(
        description: '',
        overloaded: true,
        errorMessage: 'timeout',
      );
    } catch (e, st) {
      debugPrint('VisionService error on $model: $e\n$st');
      return VisionResult(
        description: '',
        errorMessage: e.toString(),
      );
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
