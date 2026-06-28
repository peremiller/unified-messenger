// Native (Android/iOS/desktop) implementation using flutter_local_notifications.
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

class _LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    try {
      await _plugin.initialize(
          const InitializationSettings(android: android, iOS: darwin));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  @override
  Future<void> showHelp(String name) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'help_alerts',
        'Emergency help alerts',
        channelDescription: 'Fires when a network contact flags "need help"',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFFEF4444),
      ),
      iOS: DarwinNotificationDetails(
          presentAlert: true, presentSound: true, presentBadge: true),
    );
    try {
      await _plugin.show(
        name.hashCode & 0x7fffffff,
        '🆘 $name needs help',
        '$name flagged "Need help" in your network',
        details,
      );
    } catch (_) {/* ignore */}
  }
}

NotificationService createNotificationService() => _LocalNotificationService();
