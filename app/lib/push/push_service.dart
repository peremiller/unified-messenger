// Firebase Cloud Messaging — works on both mobile and web.
//
// firebase_core / firebase_messaging support web, so a single implementation
// covers everything. Everything is wrapped in try/catch and skips cleanly when
// Firebase isn't configured yet, so the app (and the web build) runs fine with
// no Firebase project at all.
//
// Web specifics:
//  - getToken needs a VAPID key (Firebase console → Cloud Messaging → Web Push
//    certificates). Pass it at build time: --dart-define=FCM_VAPID_KEY=...
//  - background push is handled by web/firebase-messaging-sw.js (service worker).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api_service.dart';
import '../firebase_options.dart';
import '../notifications/notification_service.dart';

/// Web Push VAPID public key. Supply with `--dart-define=FCM_VAPID_KEY=KEY`.
const String kWebVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Mobile background isolate. 'notification' payloads auto-display in the OS
  // tray; nothing extra needed for the help alert. (On web, background pushes
  // are handled by firebase-messaging-sw.js instead.)
}

class PushService {
  PushService(this.api);
  final ApiService api;
  final _notifications = createNotificationService();

  Future<void> init() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      await _notifications.init();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      }

      final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
      final token = kIsWeb
          ? await messaging.getToken(
              vapidKey: kWebVapidKey.isEmpty ? null : kWebVapidKey)
          : await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await api.registerFcmToken(token: token, platform: platform);
      }
      messaging.onTokenRefresh.listen(
          (t) => api.registerFcmToken(token: t, platform: platform));

      // Foreground pushes don't auto-display — surface a local notification
      // (mobile). On web the in-app WebSocket banner already covers foreground.
      FirebaseMessaging.onMessage.listen((m) {
        final name = m.data['name'] ?? m.notification?.title ?? 'A contact';
        _notifications.showHelp(name.toString());
      });
    } catch (_) {
      // Firebase not configured yet (placeholder options / missing VAPID key /
      // missing native or service-worker config). App keeps working; push off.
    }
  }
}

PushService createPushService(ApiService api) => PushService(api);
