import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_user.dart';
import 'admin_auth_provider.dart';
import 'admin_management_provider.dart';

/// State notifier managing which Admin's workspace is currently being inspected/viewed.
class AdminScopeNotifier extends Notifier<AdminUser?> {
  /// Tracks the explicitly selected admin ID for Super Admin.
  /// null means "not inspecting" — Super Admin sees only Admins Directory.
  String? _inspectedAdminId;

  @override
  AdminUser? build() {
    final currentAdmin = ref.watch(currentAdminUserProvider);
    if (currentAdmin != null && !currentAdmin.isSuperAdmin) {
      // Regular Admin is strictly locked to their own account scope
      return currentAdmin;
    }

    // For Super Admin: restore the previously selected workspace if still valid.
    // Does NOT auto-select — SA must explicitly open a workspace.
    final allAdmins = ref.watch(allAdminsStreamProvider).value;
    if (_inspectedAdminId != null && allAdmins != null) {
      final match = allAdmins
          .where((a) => a.id == _inspectedAdminId)
          .firstOrNull;
      if (match != null) return match;
    }
    // Super Admin starts with no workspace selected (shows Admins Directory only).
    return null;
  }

  /// Sets the active inspected Admin scope (for Super Admin).
  void inspectAdmin(AdminUser admin) {
    _inspectedAdminId = admin.id;
    state = admin;
  }

  /// Exits workspace inspection — Super Admin goes back to Admins Directory only view.
  void exitInspection() {
    _inspectedAdminId = null;
    state = null;
  }

  /// Resets the active admin scope back to null (legacy alias for exitInspection).
  void clearScope() {
    exitInspection();
  }
}

/// Provider for the active Admin scope.
final activeAdminScopeProvider =
    NotifierProvider<AdminScopeNotifier, AdminUser?>(() {
      return AdminScopeNotifier();
    });

/// Indicates whether the Super Admin is currently inspecting an Admin's workspace.
final isInspectingAdminWorkspaceProvider = Provider<bool>((ref) {
  final isSuper = ref.watch(isSuperAdminProvider);
  final activeScope = ref.watch(activeAdminScopeProvider);
  return isSuper && activeScope != null;
});
