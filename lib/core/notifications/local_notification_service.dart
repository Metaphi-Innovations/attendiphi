import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../logger/app_logger.dart';
import 'notification_service.dart';

/// Local-only notifications — no Firebase Cloud Messaging.
///
/// Used when `USE_SUPABASE_DATA=true`. Alerts come from Supabase polling /
/// Realtime; OS banners use [FlutterLocalNotificationsPlugin]. Device id is a
/// stable local UUID stored in SharedPreferences (not an FCM token).
class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _injectedLocalNotifications = localNotifications;

  final FlutterLocalNotificationsPlugin? _injectedLocalNotifications;
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  final _notificationTappedController =
      StreamController<NotificationPayload>.broadcast();
  final _tokenRefreshController = StreamController<String>.broadcast();

  bool _isInitialized = false;
  static const _deviceIdKey = 'attendiphi_local_device_id';

  @override
  Stream<NotificationPayload> get onNotificationTapped =>
      _notificationTappedController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<void> initialize() async {
    if (kIsWeb) {
      AppLogger.info(
        'Local notifications skipped on web (in-app polling only).',
        tag: 'LocalNotificationService',
      );
      return;
    }
    if (_isInitialized) return;

    _notificationsPlugin =
        _injectedLocalNotifications ?? FlutterLocalNotificationsPlugin();
    await _initLocalNotifications();
    await requestPermissions();
    _isInitialized = true;
    AppLogger.info(
      'LocalNotificationService initialized (no FCM).',
      tag: 'LocalNotificationService',
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidInitSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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
        if (payloadString == null || payloadString.isEmpty) return;
        try {
          final map = jsonDecode(payloadString) as Map<String, dynamic>;
          _notificationTappedController.add(NotificationPayload.fromMap(map));
        } catch (e) {
          AppLogger.error(
            'Error parsing local notification payload: $e',
            tag: 'LocalNotificationService',
          );
        }
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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
      if (!_isInitialized) {
        _notificationsPlugin =
            _injectedLocalNotifications ?? FlutterLocalNotificationsPlugin();
      }
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? true;
      }
      final ios = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e, st) {
      AppLogger.error(
        'Failed to request local notification permission: $e',
        error: e,
        stackTrace: st,
        tag: 'LocalNotificationService',
      );
      return false;
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    // Stable local device id — not an FCM token.
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await prefs.setString(_deviceIdKey, id);
      }
      return id;
    } catch (_) {
      return const Uuid().v4();
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
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  @override
  void dispose() {
    _notificationTappedController.close();
    _tokenRefreshController.close();
  }
}
