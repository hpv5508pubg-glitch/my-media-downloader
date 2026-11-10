import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String channelId = 'media_downloader_progress';
  static const String channelName = 'Media Downloader Progress';
  static const String channelDescription =
      'Shows active download progress, speed, and completion status';

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // Create persistent high-priority notification channel
    final androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.low, // Low importance avoids ringing audio on every % update
      enableVibration: false,
      playSound: false,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    _initialized = true;
  }

  /// Update foreground progress notification for a downloading task
  Future<void> showDownloadProgress({
    required int notificationId,
    required String title,
    required double progress,
    required double speedMbPerSec,
    required String etaFormatted,
  }) async {
    if (!_initialized) await init();

    final clampedProgress = progress.clamp(0.0, 100.0);
    final speedText = '${speedMbPerSec.toStringAsFixed(2)} MB/s';
    final bodyText = '${clampedProgress.toStringAsFixed(1)}% • $speedText • ETA: $etaFormatted';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: clampedProgress.toInt(),
      ongoing: true,
      autoCancel: false,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      title,
      bodyText,
      notificationDetails,
    );
  }

  /// Display a completion notification once the file is persisted to Scoped Storage
  Future<void> showDownloadComplete({
    required int notificationId,
    required String title,
    required String filename,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      'Tải hoàn tất: $title',
      'Đã lưu thành công vào /Music/$filename',
      notificationDetails,
    );
  }

  /// Display a failure notification if an error occurs
  Future<void> showDownloadError({
    required int notificationId,
    required String title,
    required String error,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      notificationId,
      'Tải thất bại: $title',
      error,
      notificationDetails,
    );
  }

  /// Cancel specific task notification
  Future<void> cancel(int notificationId) async {
    await _notificationsPlugin.cancel(notificationId);
  }

  /// Cancel all active notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
