import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../../../services/attendiphi_email_service.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/admin_device_service.dart';
import '../../data/datasources/admin_password_reset_service.dart';
import '../../data/datasources/admin_remote_data_source.dart';
import '../../data/datasources/email_credentials_service.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/admin_password_hasher.dart';
import '../../domain/entities/admin_user.dart';

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
  return EmailCredentialsService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final adminPasswordResetServiceProvider =
    Provider<AdminPasswordResetService>((ref) {
  return AdminPasswordResetService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
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
    this.sessionResolved = true,
    this.sessionPassword,
  });

  final User? user;
  final AdminUser? currentAdmin;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;
  final bool sessionResolved;

  /// In-memory login secret used to authorize credential emails. Never persisted.
  final String? sessionPassword;

  bool get isSuperAdmin => currentAdmin?.isSuperAdmin ?? false;

  AdminAuthState copyWith({
    User? user,
    AdminUser? currentAdmin,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    bool? sessionResolved,
    String? sessionPassword,
    bool clearError = false,
    bool clearAdmin = false,
    bool clearSessionPassword = false,
  }) {
    return AdminAuthState(
      user: user ?? this.user,
      currentAdmin: clearAdmin ? null : (currentAdmin ?? this.currentAdmin),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      sessionResolved: sessionResolved ?? this.sessionResolved,
      sessionPassword: clearSessionPassword
          ? null
          : (sessionPassword ?? this.sessionPassword),
    );
  }
}

/// Notifier managing Multi-Role Administrator authentication.
class AdminAuthNotifier extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() {
    final auth = ref.watch(firebaseAuthProvider);
    final sub = auth?.authStateChanges().listen(_onAuthChanged);
    ref.onDispose(() => sub?.cancel());
    final user = auth?.currentUser;
    if (user != null) {
      Future.microtask(() => _hydrate(user));
      return AdminAuthState(
        user: user,
        isLoading: true,
        sessionResolved: false,
      );
    }
    return const AdminAuthState(sessionResolved: true);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      state = const AdminAuthState(sessionResolved: true);
      return;
    }
    if (state.isAuthenticated && state.currentAdmin?.id == user.uid) {
      return;
    }
    // Ignore secondary-app provision spillover: a different UID must not
    // replace / sign out the logged-in Super Admin mid Admin-create.
    if (state.isAuthenticated &&
        state.currentAdmin != null &&
        user.uid != state.currentAdmin!.id) {
      AppLogger.warning(
        'Ignoring Auth spillover uid (primary Admin session preserved)',
        tag: 'AdminAuth',
      );
      return;
    }
    await _hydrate(user);
  }

  Future<void> _hydrate(User user) async {
    try {
      final admin =
          await ref.read(adminRepositoryProvider).getAdminById(user.uid);
      if (admin == null || !admin.isActive) {
        await ref.read(firebaseAuthProvider)?.signOut();
        state = const AdminAuthState(sessionResolved: true);
        return;
      }
      state = AdminAuthState(
        user: user,
        currentAdmin: admin,
        isAuthenticated: true,
        sessionResolved: true,
      );
    } catch (_) {
      state = const AdminAuthState(sessionResolved: true);
    }
  }

  /// Firebase Auth password check, then Firestore admin profile by UID.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true, sessionResolved: true);

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final auth = ref.read(firebaseAuthProvider);

    if (auth == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication is unavailable. Please try again.',
      );
      return false;
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        await auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid Admin email or password.',
        );
        return false;
      }

      final adminUser =
          await ref.read(adminRepositoryProvider).getAdminById(uid);
      if (adminUser == null) {
        await auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid Admin email or password.',
        );
        return false;
      }
      if (!adminUser.isActive) {
        await auth.signOut();
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'This Admin account has been deactivated by the Super Admin.',
        );
        return false;
      }
      return await _finishAdminSignIn(adminUser, cleanPassword, cleanEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Too many attempts. Please try again later.',
        );
        return false;
      }
      if (e.code == 'network-request-failed') {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Network error. Please try again.',
        );
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid Admin email or password.',
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid Admin email or password.',
      );
      return false;
    }
  }

  Future<bool> _finishAdminSignIn(
    AdminUser adminUser,
    String password,
    String email,
  ) async {
    final updatedAdmin = adminUser.copyWith(lastLoginAt: DateTime.now());
    await attachFirebaseAuthSession(email: email, password: password);
    try {
      await ref.read(adminRepositoryProvider).updateAdmin(updatedAdmin);
    } catch (_) {}

    state = AdminAuthState(
      isLoading: false,
      isAuthenticated: true,
      sessionResolved: true,
      currentAdmin: updatedAdmin,
      sessionPassword: password,
      user: ref.read(firebaseAuthProvider)?.currentUser,
    );

    try {
      await ref.read(adminDeviceServiceProvider).registerAdminDevice(
            adminEmail: email,
            uid: updatedAdmin.id,
          );
    } catch (_) {}

    AppLogger.info(
      'Admin "${adminUser.name}" (${adminUser.role.label}) logged in',
      tag: 'AdminAuth',
    );
    return true;
  }

  /// Kept for API compatibility. Hardcoded Super Admin login is removed.
  Future<bool> superAdminAutoLogin() async {
    AppLogger.warning(
      'superAdminAutoLogin is disabled; use Firebase Auth',
      tag: 'AdminAuth',
    );
    return false;
  }

  /// Resets the logged-in admin's password in Firestore and updates the session.
  Future<bool> resetPassword({required String newPassword}) async {
    final current = state.currentAdmin;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final salt = AdminPasswordHasher.generateSalt();
      final hashed = AdminPasswordHasher.hash(newPassword.trim(), salt);
      final updatedAdmin = current.copyWith(
        plainPassword: '',
        passwordHash: hashed,
        passwordSalt: salt,
        mustResetPassword: false,
        lastLoginAt: DateTime.now(),
      );

      final repo = ref.read(adminRepositoryProvider);
      try {
        await ref.read(firebaseAuthProvider)?.currentUser?.updatePassword(
              newPassword.trim(),
            );
      } catch (_) {}
      await repo.updateAdmin(updatedAdmin);

      state = state.copyWith(
        isLoading: false,
        currentAdmin: updatedAdmin,
        sessionPassword: newPassword.trim(),
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
    state = const AdminAuthState(
      isAuthenticated: false,
      sessionResolved: true,
      sessionPassword: null,
    );
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
