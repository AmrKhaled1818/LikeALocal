import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _kTaskName = 'proximityCheck';
const _kSavedPostsCacheKey = 'proximity_saved_posts';
const _kThresholdMeters = 500.0;
const _kLastNotifKey = 'proximity_last_notif';

/// Entry point called by WorkManager in the background isolate.
/// Must be a top-level function annotated with `@pragma('vm:entry-point')`.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == _kTaskName) {
      await _runProximityCheck();
    }
    return true;
  });
}

Future<void> _runProximityCheck() async {
  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 15),
    );

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kSavedPostsCacheKey);
    if (cached == null) return;

    final posts = (jsonDecode(cached) as List).cast<Map<String, dynamic>>();

    // Throttle: skip if we notified in the last 30 minutes
    final lastMs = prefs.getInt(_kLastNotifKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - lastMs < 30 * 60 * 1000) return;

    for (final post in posts) {
      final lat = (post['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (post['lng'] as num?)?.toDouble() ?? 0.0;
      if (lat == 0.0 && lng == 0.0) continue;

      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, lat, lng);

      if (dist <= _kThresholdMeters) {
        await _showNotification(
          id: post['postId'].hashCode & 0xFFFFFF,
          title: 'Hidden gem nearby!',
          body:
              '"${post['title']}" is ${dist.toInt()} m away — check it out!',
        );
        await prefs.setInt(
            _kLastNotifKey, DateTime.now().millisecondsSinceEpoch);
        break;
      }
    }
  } catch (e) {
    debugPrint('ProximityService background check error: $e');
  }
}

Future<void> _showNotification({
  required int id,
  required String title,
  required String body,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));
  await plugin.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'proximity_channel',
        'Nearby Places',
        channelDescription:
            'Alerts when you are near a saved hidden gem',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

class ProximityService {
  /// Initialize WorkManager and register the periodic proximity check.
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(callbackDispatcher,
          isInDebugMode: false);
      await Workmanager().registerPeriodicTask(
        'proximityCheckUnique',
        _kTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: true,
        ),
      );
    } catch (e) {
      debugPrint('ProximityService.initialize error: $e');
    }
  }

  /// Cache saved-post lat/lng data in SharedPreferences so the background
  /// isolate can read it without needing Firebase.
  static Future<void> cacheSavedPosts(
      List<Map<String, dynamic>> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSavedPostsCacheKey, jsonEncode(posts));
    } catch (_) {}
  }
}
