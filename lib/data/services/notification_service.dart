import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled automatically by FCM on Android
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _local.initialize(
      const InitializationSettings(android: androidSettings),
    );

    await _setupChannel();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  static Future<void> _setupChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'like_a_local_channel',
      'LikeALocal Notifications',
      description: 'LikeALocal push notifications',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<String?> requestPermissionAndGetToken() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return await messaging.getToken();
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'like_a_local_channel',
          'LikeALocal Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> showLocalNotification(
      String title, String body) async {
    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'like_a_local_channel',
          'LikeALocal Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> createNotificationDoc({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? postId,
  }) async {
    final ref = FirebaseFirestore.instance.collection('notifications').doc();
    await ref.set({
      'notifId': ref.id,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'postId': postId,
      'read': false,
      'createdAt': Timestamp.now(),
    });
  }
}
