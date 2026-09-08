import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';
import '../constants/app_constants.dart';
import '../logger/app_logger.dart';
import 'notification_service.dart';

/// Top-level background message handler required by Firebase Cloud Messaging.
///
/// Must be annotated with `@pragma('vm:entry-point')` so the Flutter runtime
/// can invoke it in an isolated background isolate when the app is closed or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'New Attendance Submission';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        'A new attendance submission was received.';

    // If message is a data-only message and app is in background/killed, display with FlutterLocalNotificationsPlugin
    if (message.notification == null) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(
        android: androidInitSettings,
      );
      await localNotifications.initialize(settings: initSettings);

      const androidDetails = AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      await localNotifications.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: jsonEncode(message.data),
      );
    }
  } catch (e) {
    debugPrint('FCM background message handling exception: $e');
  }
}

/// Production implementation of [NotificationService] using Firebase Cloud Messaging
/// and FlutterLocalNotificationsPlugin for Android & iOS.
class FirebaseNotificationService implements NotificationService {
  FirebaseNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _injectedMessaging = messaging,
        _injectedLocalNotifications = localNotifications;

  final FirebaseMessaging? _injectedMessaging;
  final FlutterLocalNotificationsPlugin? _injectedLocalNotifications;

  late final FirebaseMessaging _firebaseMessaging;
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  final _notificationTappedController =
      StreamController<NotificationPayload>.broadcast();

  bool _isInitialized = false;

  @override
  Stream<NotificationPayload> get onNotificationTapped =>
      _notificationTappedController.stream;

  @override
  Stream<String> get onTokenRefresh {
    if (kIsWeb) return const Stream.empty();
    return _firebaseMessaging.onTokenRefresh;
  }

  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      AppLogger.info(
        'Push notifications are disabled on web per platform requirements.',
        tag: 'FirebaseNotificationService',
      );
      return;
    }

    if (_isInitialized) return;

    _firebaseMessaging = _injectedMessaging ?? FirebaseMessaging.instance;
    _notificationsPlugin =
        _injectedLocalNotifications ?? FlutterLocalNotificationsPlugin();

    // 1. Initialize local notifications for heads-up display in foreground
    await _initLocalNotifications();

    // 2. Request permissions on Android / iOS
    await requestPermissions();

    // 3. Set foreground notification presentation options for Apple devices
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Register foreground message listener
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Register background interaction listener (app in background -> user taps notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 6. Check if app was opened from a terminated state via notification tap
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      AppLogger.info(
        'App launched from terminated state via FCM: ${initialMessage.messageId}',
        tag: 'FirebaseNotificationService',
      );
      _handleMessageOpenedApp(initialMessage);
    }

    _isInitialized = true;
    AppLogger.info(
      'FirebaseNotificationService initialized successfully.',
      tag: 'FirebaseNotificationService',
    );
  }

  /// Sets up Flutter Local Notifications plugin and Android Notification Channel.
  Future<void> _initLocalNotifications() async {
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInitSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: darwinInitSettings,
      macOS: darwinInitSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payloadString = response.payload;
        if (payloadString != null && payloadString.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(payloadString);
            final payload = NotificationPayload.fromMap(map);
            _notificationTappedController.add(payload);
            AppLogger.info(
              'User tapped local notification: ${payload.title} (${payload.submissionId})',
              tag: 'FirebaseNotificationService',
            );
          } catch (e) {
            AppLogger.error(
              'Error parsing local notification payload: $e',
              tag: 'FirebaseNotificationService',
            );
          }
        }
      },
    );

    // Create high-importance notification channel for Android
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      const channel = AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      AppLogger.info(
        'Notification permission status: ${settings.authorizationStatus}',
        tag: 'FirebaseNotificationService',
      );

      return isAuthorized;
    } catch (e, st) {
      AppLogger.error(
        'Failed to request notification permission: $e',
        error: e,
        stackTrace: st,
        tag: 'FirebaseNotificationService',
      );
      return false;
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    if (kIsWeb) return null;

    try {
      final token = await _firebaseMessaging.getToken();
      AppLogger.info(
        'FCM Device Token: $token',
        tag: 'FirebaseNotificationService',
      );
      return token;
    } catch (e, st) {
      AppLogger.error(
        'Failed to get FCM Device Token: $e',
        error: e,
        stackTrace: st,
        tag: 'FirebaseNotificationService',
      );
      return null;
    }
  }

  @override
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  /// Handles FCM message received when app is in foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.info(
      'Foreground FCM received: ${message.notification?.title ?? message.data['title']}',
      tag: 'FirebaseNotificationService',
    );

    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'New Attendance Submission';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        'A new attendance submission was received.';

    final payloadMap = <String, dynamic>{
      'title': title,
      'body': body,
      ...message.data,
    };

    // Show heads-up notification banner
    showLocalNotification(
      id: message.hashCode,
      title: title,
      body: body,
      payload: jsonEncode(payloadMap),
    );
  }

  /// Handles user tapping an FCM notification (app in background or launched from terminated).
  void _handleMessageOpenedApp(RemoteMessage message) {
    AppLogger.info(
      'FCM notification opened: ${message.messageId} | Data: ${message.data}',
      tag: 'FirebaseNotificationService',
    );

    final payloadMap = <String, dynamic>{
      'title': message.notification?.title ??
          message.data['title'] as String? ??
          'New Attendance Submission',
      'body': message.notification?.body ??
          message.data['body'] as String? ??
          'A new attendance submission was received.',
      ...message.data,
    };

    final payload = NotificationPayload.fromMap(payloadMap);
    _notificationTappedController.add(payload);
  }

  @override
  void dispose() {
    _notificationTappedController.close();
  }
}
