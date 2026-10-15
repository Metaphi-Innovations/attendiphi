import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/notifications/notification_providers.dart';
import '../../data/datasources/admin_device_registrar.dart';
import '../../data/datasources/admin_password_reset_service.dart';
import '../../data/datasources/admin_remote_data_source.dart';
import '../../data/datasources/email_credentials_service.dart';
import '../../data/datasources/supabase_admin_device_service.dart';
import '../../data/datasources/supabase_admin_remote_data_source.dart';
import '../../data/repositories/admin_repository.dart';
import '../../domain/admin_password_hasher.dart';
import '../../domain/entities/admin_user.dart';

/// Provider for admin device registration (Supabase).
final adminDeviceServiceProvider = Provider<AdminDeviceRegistrar>((ref) {
  final service = SupabaseAdminDeviceService(
    notificationService: ref.watch(notificationServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for [EmailCredentialsService].
final emailCredentialsServiceProvider = Provider<EmailCredentialsService>((
  ref,
) {
  return EmailCredentialsService();
});

final adminPasswordResetServiceProvider = Provider<AdminPasswordResetService>((
  ref,
) {
  return AdminPasswordResetService();
});

/// Provider for [AdminRemoteDataSource].
final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>((ref) {
  AppLogger.info('Admin data source: Supabase', tag: 'AdminProviders');
  return SupabaseAdminRemoteDataSource();
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
    this.authUid,
    this.currentAdmin,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
    this.sessionResolved = true,
    this.sessionPassword,
  });

  /// Supabase Auth user id (string form of UUID).
  final String? authUid;
  final AdminUser? currentAdmin;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;
  final bool sessionResolved;

  /// In-memory login secret used to authorize credential emails. Never persisted.
  final String? sessionPassword;

  bool get isSuperAdmin => currentAdmin?.isSuperAdmin ?? false;

  AdminAuthState copyWith({
    String? authUid,
    AdminUser? currentAdmin,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
    bool? sessionResolved,
    String? sessionPassword,
    bool clearError = false,
    bool clearAdmin = false,
    bool clearSessionPassword = false,
    bool clearAuthUid = false,
  }) {
    return AdminAuthState(
      authUid: clearAuthUid ? null : (authUid ?? this.authUid),
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

/// Notifier managing Multi-Role Administrator authentication (Supabase Auth).
class AdminAuthNotifier extends Notifier<AdminAuthState> {
  StreamSubscription<AuthState>? _supabaseAuthSub;

  @override
  AdminAuthState build() => _buildSupabase();

  AdminAuthState _buildSupabase() {
    final client = Supabase.instance.client;
    _supabaseAuthSub?.cancel();
    _supabaseAuthSub = client.auth.onAuthStateChange.listen((data) {
      unawaited(_onSupabaseAuthChanged(data.session));
    });
    ref.onDispose(() {
      _supabaseAuthSub?.cancel();
      _supabaseAuthSub = null;
    });

    final session = client.auth.currentSession;
    if (session != null) {
      Future.microtask(() => _hydrateSupabase(session));
      return AdminAuthState(
        authUid: session.user.id,
        isLoading: true,
        sessionResolved: false,
      );
    }
    return const AdminAuthState(sessionResolved: true);
  }

  Future<void> _onSupabaseAuthChanged(Session? session) async {
    if (session == null) {
      if (state.isAuthenticated) {
        state = const AdminAuthState(sessionResolved: true);
      }
      return;
    }
    if (state.isAuthenticated &&
        state.authUid == session.user.id &&
        state.currentAdmin != null) {
      return;
    }
    await _hydrateSupabase(session);
  }

  Future<void> _hydrateSupabase(Session session, {int attempt = 1}) async {
    const maxAttempts = 5;
    try {
      final email = (session.user.email ?? '').trim().toLowerCase();
      final ds = ref.read(adminRemoteDataSourceProvider);
      AdminUser? admin;
      if (ds is SupabaseAdminRemoteDataSource) {
        admin = await ds.getAdminByAuthUserId(session.user.id);
      }
      admin ??= await ref.read(adminRepositoryProvider).getAdminByEmail(email);
      if (admin == null || !admin.isActive) {
        await Supabase.instance.client.auth.signOut();
        state = const AdminAuthState(sessionResolved: true);
        return;
      }

      try {
        await Supabase.instance.client.rpc('link_own_admin_auth');
      } catch (_) {
        if (ds is SupabaseAdminRemoteDataSource) {
          try {
            await ds.linkAuthUserId(
              adminId: admin.id,
              authUserId: session.user.id,
            );
          } catch (_) {}
        }
      }

      state = AdminAuthState(
        authUid: session.user.id,
        currentAdmin: admin,
        isAuthenticated: true,
        sessionResolved: true,
      );
    } catch (e, st) {
      AppLogger.warning(
        'Admin session hydrate failed (attempt $attempt/$maxAttempts): $e',
        tag: 'AdminAuth',
      );
      // Transient network/RLS blip — keep session unresolved and retry instead
      // of clearing auth (which made dashboards look randomly empty).
      if (attempt < maxAttempts) {
        state = AdminAuthState(
          authUid: session.user.id,
          isLoading: true,
          sessionResolved: false,
        );
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        final still = Supabase.instance.client.auth.currentSession;
        if (still?.user.id == session.user.id) {
          await _hydrateSupabase(session, attempt: attempt + 1);
        }
        return;
      }
      AppLogger.error(
        'Admin session hydrate exhausted retries',
        error: e,
        stackTrace: st,
        tag: 'AdminAuth',
      );
      state = AdminAuthState(
        authUid: session.user.id,
        isLoading: false,
        sessionResolved: true,
        errorMessage: 'Could not load admin profile. Please refresh.',
      );
    }
  }

  /// Signs in with email/password via Supabase Auth.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      sessionResolved: true,
    );

    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    return _signInSupabase(cleanEmail, cleanPassword);
  }

  Future<bool> _signInSupabase(String cleanEmail, String cleanPassword) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      return await _completeSupabaseLogin(
        session: response.session,
        user: response.user,
        cleanEmail: cleanEmail,
        cleanPassword: cleanPassword,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('network') || msg.contains('fetch')) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Network error. Please try again.',
        );
        return false;
      }
      if (e.statusCode == '429' || msg.contains('rate limit')) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Too many attempts. Please try again later.',
        );
        return false;
      }
      AppLogger.warning(
        'Supabase Auth sign-in failed: ${e.message}',
        tag: 'AdminAuth',
      );
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

  Future<bool> _completeSupabaseLogin({
    required Session? session,
    required User? user,
    required String cleanEmail,
    required String cleanPassword,
  }) async {
    if (user == null || session == null) {
      await Supabase.instance.client.auth.signOut();
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid Admin email or password.',
      );
      return false;
    }

    final ds = ref.read(adminRemoteDataSourceProvider);
    AdminUser? adminUser;
    if (ds is SupabaseAdminRemoteDataSource) {
      adminUser = await ds.getAdminByAuthUserId(user.id);
    }
    adminUser ??= await ref
        .read(adminRepositoryProvider)
        .getAdminByEmail(cleanEmail);

    if (adminUser == null) {
      await Supabase.instance.client.auth.signOut();
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'No Admin profile found in Supabase for this email. '
            'Confirm Phase 3 seed applied (admins table).',
      );
      return false;
    }
    if (!adminUser.isActive) {
      await Supabase.instance.client.auth.signOut();
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'This Admin account has been deactivated by the Super Admin.',
      );
      return false;
    }

    // Prefer SECURITY DEFINER RPC — regular admins cannot UPDATE admins (RLS).
    try {
      await Supabase.instance.client.rpc('link_own_admin_auth');
    } catch (_) {
      if (ds is SupabaseAdminRemoteDataSource) {
        try {
          await ds.linkAuthUserId(adminId: adminUser.id, authUserId: user.id);
        } catch (_) {}
      }
    }

    return _finishAdminSignIn(
      adminUser,
      cleanPassword,
      cleanEmail,
      authUid: user.id,
    );
  }

  Future<bool> _finishAdminSignIn(
    AdminUser adminUser,
    String password,
    String email, {
    required String authUid,
  }) async {
    // last_login_at: regular admins cannot UPDATE admins under RLS.
    try {
      await Supabase.instance.client.rpc('touch_own_admin_login');
    } catch (_) {
      try {
        await ref
            .read(adminRepositoryProvider)
            .updateAdmin(adminUser.copyWith(lastLoginAt: DateTime.now()));
      } catch (_) {}
    }

    final signedInAdmin = adminUser.copyWith(lastLoginAt: DateTime.now());
    state = AdminAuthState(
      isLoading: false,
      isAuthenticated: true,
      sessionResolved: true,
      currentAdmin: signedInAdmin,
      sessionPassword: password,
      authUid: authUid,
    );

    try {
      await ref
          .read(adminDeviceServiceProvider)
          .registerAdminDevice(adminEmail: email, uid: signedInAdmin.id);
    } catch (_) {}

    AppLogger.info(
      'Admin "${adminUser.name}" (${adminUser.role.label}) logged in '
      '(Supabase Auth)',
      tag: 'AdminAuth',
    );
    return true;
  }

  /// Resets the logged-in admin's password.
  ///
  /// Auth password update alone is not enough: [AdminUser.mustResetPassword]
  /// lives in `public.admins` and regular admins cannot UPDATE that table
  /// under RLS. Clearing the flag requires [complete_own_password_reset].
  /// We re-read the row afterward so a silent RLS no-op cannot leave the
  /// admin stuck on /admin-reset-password after the next login.
  Future<bool> resetPassword({required String newPassword}) async {
    final current = state.currentAdmin;
    if (current == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final salt = AdminPasswordHasher.generateSalt();
      final hashed = AdminPasswordHasher.hash(newPassword.trim(), salt);
      final client = Supabase.instance.client;

      await client.auth.updateUser(
        UserAttributes(password: newPassword.trim()),
      );

      // Link Auth uid first (best-effort) so the RPC WHERE clause matches.
      try {
        await client.rpc('link_own_admin_auth');
      } catch (_) {}

      await client.rpc(
        'complete_own_password_reset',
        params: {'p_password_hash': hashed, 'p_password_salt': salt},
      );

      // Confirm Postgres flag is actually cleared (not just local state).
      final ds = ref.read(adminRemoteDataSourceProvider);
      AdminUser? refreshed;
      final authUid = client.auth.currentUser?.id;
      if (ds is SupabaseAdminRemoteDataSource && authUid != null) {
        refreshed = await ds.getAdminByAuthUserId(authUid);
      }
      refreshed ??= await ref
          .read(adminRepositoryProvider)
          .getAdminByEmail(current.email);

      if (refreshed == null || refreshed.mustResetPassword) {
        throw StateError(
          'Password updated in Auth, but must_reset_password is still true '
          'in the database. Apply migration '
          '20261014183000_admin_password_reset_harden.sql '
          '(complete_own_password_reset RPC).',
        );
      }

      final updatedAdmin = refreshed.copyWith(
        passwordHash: hashed,
        passwordSalt: salt,
        mustResetPassword: false,
        lastLoginAt: DateTime.now(),
        passwordUpdatedAt: DateTime.now(),
      );

      state = state.copyWith(
        isLoading: false,
        currentAdmin: updatedAdmin,
        sessionPassword: newPassword.trim(),
      );

      AppLogger.info(
        'Password successfully updated for admin: ${current.email}',
        tag: 'AdminAuth',
      );
      return true;
    } catch (e) {
      AppLogger.error('Failed to reset password: $e', tag: 'AdminAuth');
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Failed to finish password reset. Please try again. If this '
            'keeps happening, ask a Super Admin to clear must_reset_password '
            'for your account.',
      );
      return false;
    }
  }

  /// Signs out of admin session.
  Future<void> signOut() async {
    try {
      await ref.read(adminDeviceServiceProvider).unregisterAdminDevice();
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    state = const AdminAuthState(
      isAuthenticated: false,
      sessionResolved: true,
      sessionPassword: null,
    );
  }
}

/// Provider for [AdminAuthNotifier].
final adminAuthProvider = NotifierProvider<AdminAuthNotifier, AdminAuthState>(
  () {
    return AdminAuthNotifier();
  },
);

/// Convenience provider to check if currently signed in user is a Super Admin.
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(adminAuthProvider).isSuperAdmin;
});

/// Convenience provider to get current logged in AdminUser.
final currentAdminUserProvider = Provider<AdminUser?>((ref) {
  return ref.watch(adminAuthProvider).currentAdmin;
});
