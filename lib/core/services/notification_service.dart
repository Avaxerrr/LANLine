import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _appInForeground = true;

  set appInForeground(bool value) => _appInForeground = value;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Platform.isAndroid) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        await _plugin.initialize(
          settings: const InitializationSettings(android: androidSettings),
        );
        // Request notification permission on Android 13+
        await _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      } else {
        await _plugin.initialize(
          settings: const InitializationSettings(),
        );
      }
      _initialized = true;
    } catch (e) {
      // Silently fail on unsupported platforms
      _initialized = false;
    }
  }

  Future<void> showMessageNotification({
    required String sender,
    required String message,
    String? roomName,
  }) async {
    if (!_initialized || _appInForeground) return;

    const androidDetails = AndroidNotificationDetails(
      'lanline_messages',
      'Messages',
      channelDescription: 'LANLine chat messages',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: roomName != null ? '$sender in $roomName' : sender,
      body: message,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showFileNotification({
    required String sender,
    required String fileName,
    bool isOffer = false,
  }) async {
    if (!_initialized || _appInForeground) return;

    const androidDetails = AndroidNotificationDetails(
      'lanline_files',
      'File Transfers',
      channelDescription: 'LANLine file transfer notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: isOffer ? 'File offer from $sender' : 'File received from $sender',
      body: fileName,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }
}
