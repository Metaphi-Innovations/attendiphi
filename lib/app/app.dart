import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import '../core/logger/app_logger.dart';
import '../core/notifications/notification_providers.dart';
import 'router/app_router.dart';
import 'router/route_names.dart';
import 'theme/app_theme.dart';

/// Root application widget configuring routing, push notifications, and theme.
class QrCheckInApp extends ConsumerStatefulWidget {
  const QrCheckInApp({super.key});

  @override
  ConsumerState<QrCheckInApp> createState() => _QrCheckInAppState();
}

class _QrCheckInAppState extends ConsumerState<QrCheckInApp> {
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    // Initialize push notifications asynchronously on mobile
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initNotifications();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache MetaPhi brand images so they display instantly everywhere
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      precacheImage(
        const AssetImage('assets/images/metaphi_tagline_logo.webp'),
        context,
      );
      precacheImage(
        const AssetImage('assets/images/metaphi_logo.webp'),
        context,
      );
      precacheImage(
        const AssetImage('assets/images/attendiphi_logo.png'),
        context,
      );
      precacheImage(const AssetImage('assets/images/RISE.png'), context);
      precacheImage(const AssetImage('assets/images/BNI.jpg'), context);
    }
  }

  Future<void> _initNotifications() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize();
    } catch (e, st) {
      AppLogger.error(
        'Failed to initialize NotificationService in QrCheckInApp: $e',
        error: e,
        stackTrace: st,
        tag: 'QrCheckInApp',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Listen for notification tap events to perform deep-link navigation
    ref.listen(notificationTappedStreamProvider, (previous, next) {
      next.whenData((payload) {
        AppLogger.info(
          'Deep-linking from notification tap to Admin Dashboard for submission ${payload.submissionId}',
          tag: 'QrCheckInApp',
        );
        router.go(RouteNames.adminDashboard);
      });
    });

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
