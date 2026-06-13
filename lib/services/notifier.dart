import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Cross-platform pop-ups. Android uses a notification channel; desktop
/// (Windows/Linux/macOS) uses native notifications. This is the "reach out to
/// the user" channel — wire it to reminders or proactive triggers later.
class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const settings = InitializationSettings(android: android, linux: linux);
    await _plugin.initialize(settings);

    // Android 13+ needs explicit runtime permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _ready = true;
  }

  Future<void> popup(String title, String body) async {
    if (!_ready) await init();
    const android = AndroidNotificationDetails(
      'hermes_default',
      'Hermes',
      channelDescription: 'Messages and reminders from Hermes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7fffffff,
      title,
      body,
      details,
    );
  }
}
