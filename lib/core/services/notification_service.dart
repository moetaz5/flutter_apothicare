import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Global Navigation Key accessor for notification tap redirects
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Initialize local notifications for iOS and Android
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    navigatorKey = navKey;

    // 1. Android Initialization Settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. iOS Initialization Settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 3. Create high-importance Android Notification Channel
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'apothicare_chat_channel_v4',
            'Messages & Alertes Apothicare',
            description: 'Canal instantané des messages et alertes Apothicare',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
        // Request runtime permission for Android 13+
        await androidImplementation.requestNotificationsPermission();
      }
    }

    _isInitialized = true;
  }

  /// Request permissions on demand
  static Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final iosImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  /// Show standard system notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'apothicare_chat_channel_v4',
      'Messages & Alertes Apothicare',
      channelDescription: 'Canal instantané des messages et alertes Apothicare',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF71A246),
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Test notification helper
  static Future<void> showTestNotification() async {
    await showNotification(
      id: 9999,
      title: '🔔 Test Notification Apothicare',
      body: 'Les notifications système fonctionnent parfaitement sur votre téléphone !',
      payload: 'actualite',
    );
  }

  /// Helper for new message notification
  static Future<void> showMessageNotification({
    required String senderName,
    required String message,
    String? payload,
  }) async {
    final notifId = DateTime.now().millisecondsSinceEpoch % 1000000;
    await showNotification(
      id: notifId,
      title: '💬 Nouveau message de $senderName',
      body: message,
      payload: payload ?? 'message',
    );
  }

  /// Helper for new actualité notification
  static Future<void> showActualiteNotification({
    required String titre,
    required String resume,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '📰 Nouvelle actualité Apothicare',
      body: titre,
      payload: payload ?? 'actualite',
    );
  }

  /// Helper for dispensation notification
  static Future<void> showDispensationNotification({
    required String patientName,
    required String medicament,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '💊 Nouvelle dispensation enregistrée',
      body: '$patientName : $medicament',
      payload: payload ?? 'dispensation',
    );
  }

  /// Handle tap on system notification
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || navigatorKey?.currentState == null) return;

    if (payload.contains('message') || payload.contains('chat')) {
      navigatorKey!.currentState!.pushNamed('/messagerie');
    } else if (payload.contains('actualite')) {
      navigatorKey!.currentState!.pushNamed('/actualites');
    } else if (payload.contains('observance') || payload.contains('dispensation')) {
      navigatorKey!.currentState!.pushNamed('/observance');
    } else if (payload.contains('garde')) {
      navigatorKey!.currentState!.pushNamed('/gardes-map');
    }
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
