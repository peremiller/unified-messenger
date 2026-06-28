// Web / unsupported fallback: no OS notifications (the app still shows an
// in-app alert banner). Keeps flutter_local_notifications out of the web build.
import 'notification_service.dart';

class _NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> showHelp(String name) async {}
}

NotificationService createNotificationService() => _NoopNotificationService();
