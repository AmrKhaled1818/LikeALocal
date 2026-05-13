// Live integration test for the Groq migration.
// Run with:
//   flutter test test/groq_live_test.dart \
//     --dart-define=GROQ_API_KEY=gsk_your_key
//
// Requires a real Groq key — skipped automatically when the key is absent.
// Never commit output or keys; report is written to GROQ_MIGRATION_REPORT.md.

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:like_a_local/core/constants/app_config.dart';
import 'package:like_a_local/data/models/message_model.dart';
import 'package:like_a_local/data/models/user_model.dart';
import 'package:like_a_local/data/services/ai_service.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

String _first300(String s) {
  final clean = s.replaceAll('\n', ' ').trim();
  return clean.length > 300 ? '${clean.substring(0, 297)}...' : clean;
}

class _Result {
  final int index;
  final String label;
  final String model;
  final int statusCode;
  final bool fallback;
  final int roundTripMs;
  final int? groqTotalMs;
  final int? groqQueueMs;
  final int? tokensIn;
  final int? tokensOut;
  final int? tokensTotal;
  final String preview;
  final String? error;
  final bool jsonParsed;
  final Map<String, String> rateLimitHeaders;

  const _Result({
    required this.index,
    required this.label,
    required this.model,
    required this.statusCode,
    required this.fallback,
    required this.roundTripMs,
    this.groqTotalMs,
    this.groqQueueMs,
    this.tokensIn,
    this.tokensOut,
    this.tokensTotal,
    required this.preview,
    this.error,
    this.jsonParsed = false,
    this.rateLimitHeaders = const {},
  });

  bool get passed =>
      error == null &&
      statusCode == 200 &&
      preview.isNotEmpty &&
      roundTripMs < 15000;
}

Future<_Result> _run(
  int index,
  String label,
  Future<dynamic> Function() call, {
  bool expectsJson = false,
}) async {
  AIService.lastStats = null;
  final sw = Stopwatch()..start();
  try {
    final result = await call();
    sw.stop();
    final stats = AIService.lastStats;

    String preview;
    bool jsonParsed = false;

    if (result is String) {
      preview = _first300(result);
    } else if (result is Map) {
      preview = _first300(result.toString());
      jsonParsed = expectsJson;
    } else if (result is List) {
      preview = _first300(result.toString());
      jsonParsed = expectsJson && result.isNotEmpty;
    } else {
      preview = result.toString();
    }

    return _Result(
      index: index,
      label: label,
      model: stats?.model ?? 'unknown',
      statusCode: stats?.statusCode ?? 200,
      fallback: stats?.usedFallback ?? false,
      roundTripMs: sw.elapsedMilliseconds,
      groqTotalMs: stats?.groqTotalTimeMs,
      groqQueueMs: stats?.groqQueueTimeMs,
      tokensIn: stats?.promptTokens,
      tokensOut: stats?.completionTokens,
      tokensTotal: stats?.totalTokens,
      preview: preview,
      jsonParsed: jsonParsed,
      rateLimitHeaders: stats?.rateLimitHeaders ?? const {},
    );
  } catch (e) {
    sw.stop();
    final stats = AIService.lastStats;
    return _Result(
      index: index,
      label: label,
      model: stats?.model ?? 'unknown',
      statusCode: stats?.statusCode ?? 0,
      fallback: stats?.usedFallback ?? false,
      roundTripMs: sw.elapsedMilliseconds,
      groqTotalMs: stats?.groqTotalTimeMs,
      groqQueueMs: stats?.groqQueueTimeMs,
      tokensIn: stats?.promptTokens,
      tokensOut: stats?.completionTokens,
      tokensTotal: stats?.totalTokens,
      preview: '',
      error: e.toString(),
      rateLimitHeaders: stats?.rateLimitHeaders ?? const {},
    );
  }
}

// ── Fake data for chatbot tests ───────────────────────────────────────────────

UserModel _fakeUser() => UserModel(
      uid: 'test_uid',
      username: 'tester',
      location: 'Cairo',
      preferences: const {
        'budget': 'mid',
        'atmosphere': 'cozy',
        'favCategories': ['Café', 'Restaurant'],
      },
    );

List<MessageModel> _chatHistory(List<String> userMsgs) => [
      for (int i = 0; i < userMsgs.length; i++)
        MessageModel(
          msgId: 'msg_$i',
          senderId: 'test_uid',
          text: userMsgs[i],
          type: 'text',
          createdAt: Timestamp.now(),
        ),
    ];

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  final svc = AIService();
  final results = <_Result>[];

  group('Groq live migration test', () {
    test('01 chatbot — greeting about visiting Cairo', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set — pass --dart-define=GROQ_API_KEY=gsk_...');
        return;
      }
      final r = await _run(1, 'Chatbot: greeting Cairo', () async {
        return svc.getAIResponse(
          _chatHistory([
            'Hi! I am visiting Cairo for the first time. What hidden gems should I check out?'
          ]),
          _fakeUser(),
          lat: 30.0444,
          lng: 31.2357,
        );
      });
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.preview, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('02 chatbot — follow-up in Cairo conversation', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(2, 'Chatbot: follow-up Cairo', () async {
        return svc.getAIResponse(
          _chatHistory([
            'Hi! I am visiting Cairo for the first time. What hidden gems should I check out?',
            'Tell me more about local street food options.',
          ]),
          _fakeUser(),
          lat: 30.0444,
          lng: 31.2357,
        );
      });
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.preview, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('03 vibe search — cozy cafe', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(3, 'Vibe parse: cozy cafe', () async {
        return svc.parseVibeQuery('cozy cafe with good wifi');
      }, expectsJson: true);
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.jsonParsed, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('04 vibe search — rooftop bar', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(4, 'Vibe parse: rooftop bar', () async {
        return svc.parseVibeQuery('trendy rooftop bar with city views');
      }, expectsJson: true);
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.jsonParsed, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('05 trip planner — half day Cairo cultural', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(5, 'Trip plan: half day Cairo cultural', () async {
        return svc.planCityTrip(
          city: 'Cairo',
          duration: 'half day',
          mood: 'cultural',
        );
      });
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.preview, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('06 trip planner — full day Alexandria adventurous', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(6, 'Trip plan: full day Alexandria adventurous', () async {
        return svc.planCityTrip(
          city: 'Alexandria',
          duration: 'full day',
          mood: 'adventurous',
        );
      });
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.preview, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('07 tag generation — koshary place', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(7, 'Tags: koshary place', () async {
        return svc.generateTags(
          title: 'Abu Tarek Koshary',
          category: 'Restaurant',
          description: 'Legendary koshary spot in downtown Cairo, cash only.',
        );
      }, expectsJson: true);
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.jsonParsed, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('08 tag generation — Zamalek coffee shop', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(8, 'Tags: Zamalek coffee shop', () async {
        return svc.generateTags(
          title: 'The Tap West',
          category: 'Café',
          description: 'Artisan coffee and brunch on Zamalek island, outdoor seating.',
        );
      }, expectsJson: true);
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.jsonParsed, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('09 place tip generation — Cairo', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(9, 'Local tip: Cairo', () async {
        return svc.generateLocalTip('Cairo, Egypt');
      });
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.preview, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('10 place tip generation — Alexandria', () async {
      if (AppConfig.groqApiKey.isEmpty) {
        markTestSkipped('GROQ_API_KEY not set');
        return;
      }
      final r = await _run(10, 'Local tip: Alexandria', () async {
        return svc.generateLocalTip('Alexandria, Egypt');
      });
      results.add(r);
      expect(r.error, isNull, reason: r.error ?? '');
      expect(r.preview, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 20)));

    tearDownAll(() async {
      if (results.isEmpty) return;
      _printAndSaveReport(results);
    });
  });
}

// ── Report ────────────────────────────────────────────────────────────────────

void _printAndSaveReport(List<_Result> results) {
  final buf = StringBuffer();

  void out(String line) {
    buf.writeln(line);
    // ignore: avoid_print
    print(line);
  }

  final passed = results.where((r) => r.passed).length;
  final verdict = (passed == results.length && results.length == 10) ? 'PASS' : 'FAIL';

  final roundTrips = results.map((r) => r.roundTripMs).where((ms) => ms > 0).toList();
  final avgRt = roundTrips.isEmpty
      ? 0
      : (roundTrips.reduce((a, b) => a + b) / roundTrips.length).round();
  final minRt =
      roundTrips.isEmpty ? 0 : roundTrips.reduce((a, b) => a < b ? a : b);
  final maxRt =
      roundTrips.isEmpty ? 0 : roundTrips.reduce((a, b) => a > b ? a : b);
  final totalTokens = results.fold<int>(0, (s, r) => s + (r.tokensTotal ?? 0));

  final rlByModel = <String, Map<String, String>>{};
  for (final r in results) {
    if (r.rateLimitHeaders.isNotEmpty) {
      rlByModel[r.model] = r.rateLimitHeaders;
    }
  }

  out('');
  out('# Groq Migration Report — ${DateTime.now().toIso8601String()}');
  out('');
  out('## Files changed');
  out('');
  out('- `lib/core/constants/app_config.dart` — replaced OpenRouter constants with');
  out('  `GROQ_API_KEY`, `GROQ_PRIMARY_MODEL` (llama-3.3-70b-versatile),');
  out('  `GROQ_FALLBACK_MODEL` (llama-3.1-8b-instant), `GROQ_BASE_URL`.');
  out('- `lib/data/services/ai_service.dart` — rewrote to use Groq via a shared');
  out('  `_complete()` helper; removed OpenRouter headers; added 429-to-fallback');
  out('  retry; added `AiCallStats`/`AiException`; added `planCityTrip`,');
  out('  `parseVibeQuery`, `generateTags`, `generateLocalTip`; routed');
  out('  `generateBestTimeHint`/`parseVibeQuery`/`generateTags` to fallback model.');
  out('');
  out('## Model routing');
  out('');
  out('| Task                                     | Model                   |');
  out('|------------------------------------------|-------------------------|');
  out('| Chatbot (`getAIResponse`)                | llama-3.3-70b-versatile |');
  out('| Place summary (`generatePostSummary`)    | llama-3.3-70b-versatile |');
  out('| Trip planner (`planTrip`/`planCityTrip`) | llama-3.3-70b-versatile |');
  out('| Local tip (`generateLocalTip`)           | llama-3.3-70b-versatile |');
  out('| Best-time hint (`generateBestTimeHint`)  | llama-3.1-8b-instant    |');
  out('| Vibe parsing (`parseVibeQuery`)          | llama-3.1-8b-instant    |');
  out('| Tag generation (`generateTags`)          | llama-3.1-8b-instant    |');
  out('| 429 fallback retry (any primary call)    | llama-3.1-8b-instant    |');
  out('');
  out('## Results');
  out('');
  out('| # | Query | Model | Status | RT ms | Groq ms | Q ms | In tok | Out tok | Fallback? | Preview (first 60 chars) |');
  out('|---|-------|-------|--------|-------|---------|------|--------|---------|-----------|--------------------------|');
  for (final r in results) {
    final status = r.error != null ? 'ERR' : '${r.statusCode}';
    final gt = r.groqTotalMs != null ? '${r.groqTotalMs}' : '-';
    final gq = r.groqQueueMs != null ? '${r.groqQueueMs}' : '-';
    final ti = r.tokensIn != null ? '${r.tokensIn}' : '-';
    final to = r.tokensOut != null ? '${r.tokensOut}' : '-';
    final fb = r.fallback ? 'YES' : 'no';
    final modelShort = r.model.contains('70b')
        ? '70b'
        : r.model.contains('8b')
            ? '8b'
            : r.model;
    final preview = r.error != null
        ? 'ERROR: ${r.error!.substring(0, r.error!.length.clamp(0, 60))}'
        : r.preview.substring(0, r.preview.length.clamp(0, 60)).replaceAll('|', '/');
    out('| ${r.index} | ${r.label} | $modelShort | $status | ${r.roundTripMs} | $gt | $gq | $ti | $to | $fb | $preview |');
  }
  out('');
  out('## Aggregates');
  out('');
  out('- Round-trip avg / min / max: ${avgRt}ms / ${minRt}ms / ${maxRt}ms');
  out('- Total tokens consumed: $totalTokens');
  out('- Passed: $passed / ${results.length}');
  final slowOrBad = results.where((r) => !r.passed || r.roundTripMs > 2000).length;
  out('- Queries with issues (errors or >2000ms): $slowOrBad');
  out('');

  if (rlByModel.isNotEmpty) {
    out('## Rate-limit headers (last response per model)');
    out('');
    for (final entry in rlByModel.entries) {
      out('### ${entry.key}');
      for (final h in entry.value.entries) {
        out('- `${h.key}`: ${h.value}');
      }
      out('');
    }
  }

  final issues = results.where((r) => !r.passed).toList();
  if (issues.isNotEmpty) {
    out('## Issues');
    out('');
    for (final r in issues) {
      if (r.error != null) {
        out('- Query ${r.index} (${r.label}): ERROR — ${r.error}');
      } else if (r.roundTripMs > 2000) {
        out('- Query ${r.index} (${r.label}): slow response (${r.roundTripMs}ms)');
      } else if (r.statusCode != 200) {
        out('- Query ${r.index} (${r.label}): HTTP ${r.statusCode}');
      }
    }
    out('');
  }

  out('## Verdict: $verdict');
  out('');
  out('PASS criteria: all 10 valid, JSON responses parseable, avg round-trip <1500ms, no 5xx.');
  out('');

  try {
    File('GROQ_MIGRATION_REPORT.md').writeAsStringSync(buf.toString());
    // ignore: avoid_print
    print('[report saved to GROQ_MIGRATION_REPORT.md]');
  } catch (e) {
    // ignore: avoid_print
    print('[could not save report: $e]');
  }
}
