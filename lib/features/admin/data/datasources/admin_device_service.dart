import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/notifications/notification_service.dart';

/// Service managing the registration and lifecycle of Admin device FCM tokens in Firestore,
/// and listening in real-time for new attendance submission events to trigger alerts.
class AdminDeviceService {
  AdminDeviceService({
    required this.firestore,
    required this.notificationService,
  });

  final FirebaseFirestore firestore;
  final NotificationService notificationService;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationsSubscription;
  String? _registeredToken;

  /// Registers the current mobile device as an active Admin device in Firestore
  /// and starts listening for real-time attendance notifications.
  Future<void> registerAdminDevice({
    required String adminEmail,
    String? uid,
  }) async {
    if (kIsWeb) return;

    try {
      // 1. Request notification permissions first
      final granted = await notificationService.requestPermissions();
      if (!granted) {
        AppLogger.warning(
          'Notification permission was not granted for Admin device.',
          tag: 'AdminDeviceService',
        );
      }

      // 2. Fetch current token and save to Firestore
      final token = await notificationService.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _saveDeviceToken(token: token, adminEmail: adminEmail, uid: uid);
      }

      // 3. Listen for token refreshes
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          notificationService.onTokenRefresh.listen((newToken) async {
        await _saveDeviceToken(token: newToken, adminEmail: adminEmail, uid: uid);
      });

      // 4. Start real-time Firestore listener for new attendance submissions
      _startAttendanceNotificationsListener();
    } catch (e, st) {
      AppLogger.error(
        'Failed to register admin device token: $e',
        error: e,
        stackTrace: st,
        tag: 'AdminDeviceService',
      );
    }
  }

  final Set<String> _knownCheckInIds = <String>{};
  bool _isInitialSnapshot = true;

  /// Listens to real-time attendance events for instant alert delivery.
  void _startAttendanceNotificationsListener() {
    _notificationsSubscription?.cancel();
    _isInitialSnapshot = true;
    _knownCheckInIds.clear();

    try {
      _notificationsSubscription = firestore
          .collection(AppConstants.checkInsCollection)
          .snapshots()
          .listen((snapshot) {
        if (_isInitialSnapshot) {
          for (final doc in snapshot.docs) {
            _knownCheckInIds.add(doc.id);
          }
          _isInitialSnapshot = false;
          AppLogger.info(
            'Admin notification listener primed with ${_knownCheckInIds.length} existing records.',
            tag: 'AdminDeviceService',
          );
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added &&
              !_knownCheckInIds.contains(change.doc.id)) {
            _knownCheckInIds.add(change.doc.id);
            final data = change.doc.data();
            if (data != null) {
              final userName = data['userName'] as String? ?? 'Attendee';
              final type = data['type'] as String? ?? 'Member';
              final locationName = data['locationName'] as String? ?? 'Venue';
              final title = '🔔 New Attendance: $userName';
              final body = '$userName ($type) checked in at $locationName.';

              AppLogger.info(
                'New attendance alert triggered: $title - $body',
                tag: 'AdminDeviceService',
              );

              notificationService.showLocalNotification(
                id: change.doc.id.hashCode,
                title: title,
                body: body,
                payload: jsonEncode({
                  'submissionId': change.doc.id,
                  'title': title,
                  'body': body,
                  'userName': userName,
                  'type': type,
                  'locationName': locationName,
                  'userPhone': (data['userPhone'] as String?) ?? '',
                }),
              );
            }
          }
        }
      }, onError: (e) {
        AppLogger.error(
          'Error in admin checkIns stream listener: $e',
          tag: 'AdminDeviceService',
        );
      });
    } catch (e) {
      AppLogger.error(
        'Failed to start attendance notifications listener: $e',
        tag: 'AdminDeviceService',
      );
    }
  }

  /// Saves or updates the device token document in Firestore.
  Future<void> _saveDeviceToken({
    required String token,
    required String adminEmail,
    String? uid,
  }) async {
    try {
      _registeredToken = token;
      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
              ? 'ios'
              : Platform.isAndroid
                  ? 'android'
                  : 'other';

      await firestore
          .collection(AppConstants.adminDevicesCollection)
          .doc(token)
          .set({
        'token': token,
        'uid': uid ?? '',
        'adminEmail': adminEmail,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      AppLogger.info(
        'Admin device token registered for $adminEmail on $platform',
        tag: 'AdminDeviceService',
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to save token to Firestore: $e',
        error: e,
        stackTrace: st,
        tag: 'AdminDeviceService',
      );
    }
  }

  /// Deactivates or removes the device token from Firestore when admin logs out.
  Future<void> unregisterAdminDevice() async {
    if (kIsWeb) return;

    try {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;

      await _notificationsSubscription?.cancel();
      _notificationsSubscription = null;

      if (_registeredToken != null) {
        await firestore
            .collection(AppConstants.adminDevicesCollection)
            .doc(_registeredToken)
            .update({
          'isActive': false,
          'loggedOutAt': FieldValue.serverTimestamp(),
        });
        _registeredToken = null;
      }
    } catch (e, st) {
      AppLogger.error(
        'Error unregistering admin device: $e',
        error: e,
        stackTrace: st,
        tag: 'AdminDeviceService',
      );
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _notificationsSubscription?.cancel();
  }
}
