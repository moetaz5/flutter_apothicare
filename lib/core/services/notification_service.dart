import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../network/api_client.dart';

/// Top-level background message handler for Firebase Cloud Messaging (FCM)
/// This function MUST be a top-level function annotated with @pragma('vm:entry-point')
/// It is called by Android OS even when the app is completely terminated/closed!
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  debugPrint('[FCM Background] Message received while app closed/background: ${message.messageId}');

  // If the message contains pure data payload without a system notification block,
  // we trigger a local notification to display in the notification bar
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title'] ?? message.data['senderName'] ?? 'Apothicare';
    final body = message.data['body'] ?? message.data['message'] ?? message.data['content'] ?? '';
    final type = message.data['type'] ?? 'message';

    if (body.toString().isNotEmpty || title.toString().isNotEmpty) {
      final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'apothicare_chat_channel_v4',
        'Messages & Alertes Apothicare',
        channelDescription: 'Canal instantané des messages et alertes Apothicare',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/launcher_icon',
      );
      await localNotif.show(
        DateTime.now().millisecondsSinceEpoch % 1000000,
        title.toString(),
        body.toString(),
        const NotificationDetails(android: androidDetails),
        payload: type.toString(),
      );
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  /// Global Navigation Key accessor for notification tap redirects
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Initialize notifications for iOS and Android (Local + Firebase Push)
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    navigatorKey = navKey;

    // 1. Android Local Initialization Settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    // 2. iOS Local Initialization Settings
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

    // 4. Initialize Firebase & FCM
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request FCM permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Present notification alert while app is in foreground
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Handle Foreground FCM Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Message received: ${message.messageId}');
        final notification = message.notification;
        final data = message.data;
        final title = notification?.title ?? data['title'] ?? data['senderName'] ?? 'Apothicare';
        final body = notification?.body ?? data['body'] ?? data['message'] ?? '';
        final payload = data['type'] ?? 'message';

        if (title.isNotEmpty || body.isNotEmpty) {
          showNotification(
            id: DateTime.now().millisecondsSinceEpoch % 1000000,
            title: title.toString(),
            body: body.toString(),
            payload: payload.toString(),
          );
        }
      });

      // Handle notification tap when app is in background (but not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM onMessageOpenedApp] Notification tapped: ${message.data}');
        final payload = message.data['type'] ?? 'message';
        _handlePayloadNavigation(payload.toString());
      });

      // Handle notification tap when app is opened from a terminated (completely closed) state
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugPrint('[FCM getInitialMessage] Launched from closed state: ${message.data}');
          final payload = message.data['type'] ?? 'message';
          Future.delayed(const Duration(milliseconds: 1000), () {
            _handlePayloadNavigation(payload.toString());
          });
        }
      });

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        syncFcmToken(ApiClient());
      });
    } catch (e) {
      debugPrint('[NotificationService] Firebase init warning: $e');
    }

    _isInitialized = true;
  }

  /// Request permissions on demand
  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        final iosImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } else if (Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        return await androidImplementation?.requestNotificationsPermission() ?? false;
      }
    } catch (_) {}
    return true;
  }

  /// Get current FCM Device Token with iOS APNs token resilience
  static Future<String?> getFcmToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          // Wait up to 3 seconds for iOS APNs token registration
          for (int i = 0; i < 3; i++) {
            await Future.delayed(const Duration(seconds: 1));
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM Token] $token');
      return token;
    } catch (e) {
      debugPrint('[FCM Token Error] $e');
      return null;
    }
  }

  /// Sync FCM Device Token with Apothicare Backend (user/updateFcmToken)
  static Future<void> syncFcmToken(ApiClient api) async {
    try {
      final token = await getFcmToken();
      if (token != null && token.isNotEmpty) {
        await api.post('user/updateFcmToken', data: {
          'fcm_token': token,
        });
        debugPrint('[FCM Sync] Token successfully registered on server: $token');
      }
    } catch (e) {
      debugPrint('[FCM Sync Error] Failed to update token on server: $e');
    }
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
      icon: '@mipmap/launcher_icon',
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

  /// Helper for medication reminder notification
  static Future<void> showRappelMedicamentNotification({
    required String medicament,
    required String posologie,
    String? payload,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '⏰ Rappel Prise de Médicament',
      body: 'Il est l\'heure de prendre : $medicament ($posologie)',
      payload: payload ?? 'rappel_medicament',
    );
  }

  /// Helper for routing payload
  static void _handlePayloadNavigation(String payload) {
    if (navigatorKey?.currentState == null) return;
    if (payload.contains('message') || payload.contains('chat')) {
      navigatorKey!.currentState!.pushNamed('/messagerie');
    } else if (payload.contains('actualite')) {
      navigatorKey!.currentState!.pushNamed('/actualites');
    } else if (payload.contains('observance') || payload.contains('dispensation') || payload.contains('rappel_medicament')) {
      navigatorKey!.currentState!.pushNamed('/observance');
    } else if (payload.contains('garde')) {
      navigatorKey!.currentState!.pushNamed('/gardes-map');
    }
  }

  /// Handle tap on system notification
  static void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    _handlePayloadNavigation(payload);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
