import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification_model.dart';

// Top-level handler required by FCM for terminated/background state
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized in main.dart before this is called.
  // We intentionally do NOT show a local notification here on Android because
  // FCM automatically shows the system notification when the app is in the
  // background / terminated. On iOS the system handles it natively.
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'splitpay_high';
  static const _channelName = 'SplitPay Notifications';
  static const _channelDesc = 'Group expenses, settlements, and activity alerts';

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Foreground messages broadcast to UI
  final _foregroundController = StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get foregroundStream => _foregroundController.stream;

  // Notification taps (background / terminated) broadcast for navigation
  final _tapController = StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get tapStream => _tapController.stream;

  Future<void> initialize() async {
    await _requestPermissions();
    await _initLocalNotifications();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false, // We display our own in-app banner
      badge: true,
      sound: true,
    );

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Background message tap (app was in background, user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Terminated app tap (app was closed, user tapped notification)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onNotificationTap(initial);
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create high-importance channel for Android 8+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  void _onForegroundMessage(RemoteMessage message) {
    // Show a system-style local notification so the user still gets a banner
    _showLocalNotification(message);

    // Broadcast to UI for in-app banner + list refresh
    final model = _messageToModel(message);
    if (model != null) _foregroundController.add(model);
  }

  void _onNotificationTap(RemoteMessage message) {
    final model = _messageToModel(message);
    if (model != null) _tapController.add(model);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final model = NotificationModel.fromFcmData(data);
      _tapController.add(model);
    } catch (_) {}
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
          color: const Color(0xFF00D09C),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  NotificationModel? _messageToModel(RemoteMessage message) {
    try {
      return NotificationModel.fromFcmData({
        ...message.data,
        if (message.notification?.title != null)
          'title': message.notification!.title,
        if (message.notification?.body != null)
          'body': message.notification!.body,
      });
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteToken() async {
    await _messaging.deleteToken();
  }

  void dispose() {
    _foregroundController.close();
    _tapController.close();
  }
}
