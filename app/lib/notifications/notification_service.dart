// Platform-agnostic notification surface. The real implementation
// (flutter_local_notifications) is only compiled on platforms with dart:io —
// the web build gets the no-op stub, so the plugin never enters the web bundle.
import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_io.dart' as impl;

abstract class NotificationService {
  Future<void> init();

  /// Show an emergency notification that [name] flagged "need help".
  Future<void> showHelp(String name);
}

NotificationService createNotificationService() =>
    impl.createNotificationService();
