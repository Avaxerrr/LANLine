import 'package:flutter/foundation.dart';

/// Lightweight notification service.
/// Currently a placeholder — notifications are logged but not shown as system notifications.
/// To enable Android system notifications, add flutter_local_notifications back
/// and install the Visual Studio ATL workload for Windows compatibility.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool _appInForeground = true;

  set appInForeground(bool value) => _appInForeground = value;

  Future<void> initialize() async {
    // No-op for now — system notifications disabled until
    // flutter_local_notifications Windows build issue is resolved
  }

  Future<void> showMessageNotification({
    required String sender,
    required String message,
    String? roomName,
  }) async {
    if (_appInForeground) return;
    debugPrint('[Notification] $sender: $message');
  }

  Future<void> showFileNotification({
    required String sender,
    required String fileName,
    bool isOffer = false,
  }) async {
    if (_appInForeground) return;
    debugPrint('[Notification] File from $sender: $fileName');
  }
}
