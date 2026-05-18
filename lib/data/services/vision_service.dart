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
  /// Per-attempt timeout. The free OpenRouter vision queue can sit on a
  /// request for 30–50s under load; 60s gives the slowest happy-path enough
  /// headroom without making a broken request feel infinite.
  static const _attemptTimeout = Duration(seconds: 60);

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
        errorMessage: 'OPENROUTER_API_KEY is not set',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _detectMimeType(imageFile);
    final dataUri = 'data:$mimeType;base64,$base64Image';
    final prompt = _buildPrompt(
        placeName: placeName.trim(), caption: caption.trim());

    // Attempt sequence: primary → fallback → primary-retry.
    // Primary first because it's the fastest happy path. Fallback covers
    // primary-model-specific outages. Primary-retry catches transient queue
    // blips after the fallback also failed (often the queue clears in
    // seconds).
    final primary = AppConfig.openRouterVisionModel;
    final fallback = AppConfig.openRouterVisionFallbackModel;
    final models = <String>[
      primary,
      if (fallback.isNotEmpty && fallback != primary) fallback,
      if (fallback.isNotEmpty && fallback != primary) primary,
    ];

    var sawTransient = false;
    String? lastError;

    for (var i = 0; i < models.length; i++) {
      final model = models[i];
      final attempt = await _callOnce(
        model: model,
        prompt: prompt,
        dataUri: dataUri,
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
      }

      // Small backoff before trying the next model so we don't hammer a
      // shared free-tier queue.
      if (i < models.length - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
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
    required String dataUri,
  }) async {
    try {
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
              'model': model,
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
              // 500 leaves enough headroom for the reasoning fallback model
              // (which eats ~250 tokens on internal reasoning before
              // producing content). Non-reasoning models naturally stop
              // well below this cap, so it doesn't bloat normal output.
              'max_tokens': 500,
              'temperature': 0.7,
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
        // OpenRouter wraps upstream provider outages as 4xx with the body
        // `{"error":{"message":"Provider returned error",...}}`. That's a
        // transient infra issue (Nvidia NIM, Google AI Studio, etc.), not
        // a malformed request — treat it as overloaded so we retry the
        // chain and show the friendly toast.
        final body = response.body;
        final isUpstreamOutage = body.contains('Provider returned error');
        debugPrint('VisionService HTTP ${response.statusCode} on $model: '
            '${body.length > 200 ? '${body.substring(0, 200)}...' : body}');
        return VisionResult(
          description: '',
          overloaded: isUpstreamOutage,
          errorMessage: 'HTTP ${response.statusCode}: $body',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        // Observed in the wild: the primary sometimes 200s with an empty
        // body after sitting on the queue for ~10s. Treat as transient so
        // the fallback gets a turn and the UI shows the friendlier
        // "AI is busy" message instead of a generic failure.
        return const VisionResult(
          description: '',
          overloaded: true,
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

      final cleaned = _cleanup(text);
      if (cleaned.isEmpty) {
        // Empty body from the model is treated as transient — the fallback
        // model often succeeds where the primary returned nothing.
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
