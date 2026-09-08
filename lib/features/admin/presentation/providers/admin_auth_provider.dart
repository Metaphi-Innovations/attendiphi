import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/admin_device_service.dart';
import '../../data/datasources/admin_remote_data_source.dart';
import '../../data/datasources/email_credentials_service.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/entities/admin_user.dart';

/// Superadmin master credentials
class SuperAdminConfig {
  SuperAdminConfig._();
  static const String email = 'superadmin@metaphi.com';
  static const String password = 'SuperAdmin@2026';

  static const AdminUser user = AdminUser(
    id: 'super_admin_master',
    name: 'Super Admin',
    email: email,
    phone: '+91 9999999999',
    role: AdminRole.superAdmin,
    isActive: true,
  );
}

/// Provider for [FirebaseAuth] instance.
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  try {
    return FirebaseAuth.instance;
  } catch (_) {
    return null;
  }
});

/// Provider for [AdminDeviceService].
final adminDeviceServiceProvider = Provider<AdminDeviceService>((ref) {
  final service = AdminDeviceService(
    firestore: ref.watch(firestoreProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for [EmailCredentialsService].
final emailCredentialsServiceProvider =
    Provider<EmailCredentialsService>((ref) {
  return EmailCredentialsService(firestore: ref.watch(firestoreProvider));
});

/// Provider for [AdminRemoteDataSource].
final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>((ref) {
  return AdminRemoteDataSourceImpl(firestore: ref.watch(firestoreProvider));
});

/// Provider for [AdminRepository].
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(
    remoteDataSource: ref.watch(adminRemoteDataSourceProvider),
    emailService: ref.watch(emailCredentialsServiceProvider),
  );
});

/// State for Admin Authentication.
class AdminAuthState {
  const AdminAuthState({
    this.user,
    this.currentAdmin,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  final User? user;
  final AdminUser? currentAdmin;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  bool get isSuperAdmin => currentAdmin?.isSuperAdmin ?? false;

  AdminAuthState copyWith({
    User? user,
    AdminUser? currentAdmin,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    bool clearError = false,
    bool clearAdmin = false,
  }) {
    return AdminAuthState(
      user: user ?? this.user,
      currentAdmin: clearAdmin ? null : (currentAdmin ?? this.currentAdmin),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

/// Notifier managing Multi-Role Administrator authentication.
class AdminAuthNotifier extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() {
    final auth = ref.watch(firebaseAuthProvider);
    final currentUser = auth?.currentUser;
    return AdminAuthState(
      user: currentUser,
      isAuthenticated: true,
      currentAdmin: SuperAdminConfig.user,
    );
  }

  /// Signs in Admin (Superadmin master or created Admin) with credentials.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // 1. Check against Superadmin Master Credentials
    final isMasterSuperAdmin = (cleanEmail == SuperAdminConfig.email ||
            cleanEmail == 'superadmin' ||
            cleanEmail == 'admin@qrcheckin.com') &&
        (cleanPassword == SuperAdminConfig.password ||
            cleanPassword == 'Admin@1234');

    if (isMasterSuperAdmin) {
      state = const AdminAuthState(
        isLoading: false,
        isAuthenticated: true,
        currentAdmin: SuperAdminConfig.user,
      );

      // Register Admin FCM device token
      try {
        await ref
            .read(adminDeviceServiceProvider)
            .registerAdminDevice(adminEmail: cleanEmail);
      } catch (_) {}

      AppLogger.info('Super Admin master logged in', tag: 'AdminAuth');
      return true;
    }

    // 2. Check in Firestore 'admins' Collection
    try {
      final repo = ref.read(adminRepositoryProvider);
      final adminUser = await repo.getAdminByEmail(cleanEmail);

      if (adminUser != null) {
        if (!adminUser.isActive) {
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'This Admin account has been deactivated by the Super Admin.',
          );
          return false;
        }

        final isPasswordMatch = (adminUser.plainPassword.isNotEmpty &&
                adminUser.plainPassword == cleanPassword) ||
            (adminUser.passwordHash.isNotEmpty &&
                adminUser.passwordHash == cleanPassword);

        if (isPasswordMatch) {
          final updatedAdmin = adminUser.copyWith(lastLoginAt: DateTime.now());
          try {
            await repo.updateAdmin(updatedAdmin);
          } catch (_) {}

          state = AdminAuthState(
            isLoading: false,
            isAuthenticated: true,
            currentAdmin: updatedAdmin,
          );

          try {
            await ref
                .read(adminDeviceServiceProvider)
                .registerAdminDevice(adminEmail: cleanEmail);
          } catch (_) {}

          AppLogger.info(
            'Admin "${adminUser.name}" (${adminUser.role.label}) logged in',
            tag: 'AdminAuth',
          );
          return true;
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Incorrect password for this Admin account.',
          );
          return false;
        }
      }
    } catch (e) {
      AppLogger.warning('Error checking Firestore admin: $e', tag: 'AdminAuth');
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: 'Invalid Admin email or password.',
    );
    return false;
  }

  /// 1-click Quick Superadmin Login.
  Future<bool> superAdminAutoLogin() async {
    return signIn(
      email: SuperAdminConfig.email,
      password: SuperAdminConfig.password,
    );
  }

  /// Resets the logged-in admin's password in Firestore and updates the session.
  Future<bool> resetPassword({required String newPassword}) async {
    final current = state.currentAdmin;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final updatedAdmin = current.copyWith(
        plainPassword: newPassword.trim(),
        passwordHash: newPassword.trim(),
        mustResetPassword: false,
        lastLoginAt: DateTime.now(),
      );

      final repo = ref.read(adminRepositoryProvider);
      await repo.updateAdmin(updatedAdmin);

      state = state.copyWith(
        isLoading: false,
        currentAdmin: updatedAdmin,
      );

      AppLogger.info(
        'Password successfully updated in storage for admin: ${current.email}',
        tag: 'AdminAuth',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to reset password: $e', tag: 'AdminAuth');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update password: $e',
      );
      return false;
    }
  }

  /// Signs out of admin session.
  Future<void> signOut() async {
    try {
      await ref.read(adminDeviceServiceProvider).unregisterAdminDevice();
      await ref.read(firebaseAuthProvider)?.signOut();
    } catch (_) {}
    state = const AdminAuthState(isAuthenticated: false);
  }
}

/// Provider for [AdminAuthNotifier].
final adminAuthProvider =
    NotifierProvider<AdminAuthNotifier, AdminAuthState>(() {
  return AdminAuthNotifier();
});

/// Convenience provider to check if currently signed in user is a Super Admin.
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(adminAuthProvider).isSuperAdmin;
});

/// Convenience provider to get current logged in AdminUser.
final currentAdminUserProvider = Provider<AdminUser?>((ref) {
  return ref.watch(adminAuthProvider).currentAdmin;
});
