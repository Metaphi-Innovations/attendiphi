import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../domain/entities/admin_user.dart';
import 'admin_auth_provider.dart';

enum AdminStatusFilter {
  all('All Statuses'),
  active('Active Only'),
  inactive('Inactive Only');

  const AdminStatusFilter(this.label);
  final String label;
}

class AdminFilterState {
  const AdminFilterState({
    this.searchQuery = '',
    this.statusFilter = AdminStatusFilter.all,
  });

  final String searchQuery;
  final AdminStatusFilter statusFilter;

  AdminFilterState copyWith({
    String? searchQuery,
    AdminStatusFilter? statusFilter,
  }) {
    return AdminFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class AdminFilterNotifier extends Notifier<AdminFilterState> {
  @override
  AdminFilterState build() => const AdminFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void setStatusFilter(AdminStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void resetFilters() {
    state = const AdminFilterState();
  }
}

final adminFilterProvider =
    NotifierProvider<AdminFilterNotifier, AdminFilterState>(() {
      return AdminFilterNotifier();
    });

/// Streams Admin accounts the current user is allowed to list.
final allAdminsStreamProvider = StreamProvider<List<AdminUser>>((ref) {
  final auth = ref.watch(adminAuthProvider);
  if (!auth.sessionResolved) {
    return pendingStreamController<List<AdminUser>>(onDispose: ref.onDispose)
        .stream;
  }
  if (!auth.isAuthenticated || auth.currentAdmin == null) {
    return Stream.value(const <AdminUser>[]);
  }
  final repo = ref.watch(adminRepositoryProvider);
  if (auth.currentAdmin!.isSuperAdmin) {
    return repo.watchAdmins();
  }
  final admin = auth.currentAdmin!;
  final creatorId = admin.id.trim().isNotEmpty
      ? admin.id.trim()
      : (admin.uid.trim().isNotEmpty
            ? admin.uid.trim()
            : (Supabase.instance.client.auth.currentUser?.id ?? '').trim());
  return repo.watchAdmins(createdBy: creatorId);
});

/// Provider for admins visible to the current authenticated administrator.
/// - Super Admin accounts are never listed (only managed via Supabase Dashboard).
/// - Super Admin can see all regular administrators.
/// - Regular Admin can ONLY see administrators created by himself.
final visibleAdminsProvider = Provider<AsyncValue<List<AdminUser>>>((ref) {
  final asyncAdmins = ref.watch(allAdminsStreamProvider);
  final isSuperAdmin = ref.watch(isSuperAdminProvider);
  final currentAdmin = ref.watch(currentAdminUserProvider);

  return asyncAdmins.whenData((admins) {
    // Never expose Super Admin profiles in Admin Management.
    final withoutSuperAdmins = admins
        .where((admin) => !admin.isSuperAdmin)
        .toList();

    if (isSuperAdmin) {
      return withoutSuperAdmins;
    }

    final currentId = (currentAdmin?.id ?? '').trim().toLowerCase();
    final currentUid = (currentAdmin?.uid ?? '').trim().toLowerCase();
    String currentAuthUid = '';
    try {
      currentAuthUid = (Supabase.instance.client.auth.currentUser?.id ?? '')
          .trim()
          .toLowerCase();
    } catch (_) {}
    final currentEmail = (currentAdmin?.email ?? '').trim().toLowerCase();
    final currentName = (currentAdmin?.name ?? '').trim().toLowerCase();

    return withoutSuperAdmins.where((admin) {
      final creator = (admin.createdBy ?? '').trim().toLowerCase();
      // Cannot see admins created by Super Admin or system master
      if (creator.isEmpty ||
          creator == 'superadmin' ||
          creator == 'super admin' ||
          creator == 'super_admin_master') {
        return false;
      }

      // Can only see admins created by himself
      return (currentId.isNotEmpty && creator == currentId) ||
          (currentUid.isNotEmpty && creator == currentUid) ||
          (currentAuthUid.isNotEmpty && creator == currentAuthUid) ||
          (currentEmail.isNotEmpty && creator == currentEmail) ||
          (currentName.isNotEmpty && creator == currentName);
    }).toList();
  });
});

/// Filtered Admins according to search query and status filter.
final filteredAdminsProvider = Provider<AsyncValue<List<AdminUser>>>((ref) {
  final asyncAdmins = ref.watch(visibleAdminsProvider);
  final filter = ref.watch(adminFilterProvider);

  return asyncAdmins.whenData((admins) {
    return admins.where((admin) {
      if (filter.statusFilter == AdminStatusFilter.active && !admin.isActive) {
        return false;
      }
      if (filter.statusFilter == AdminStatusFilter.inactive && admin.isActive) {
        return false;
      }
      if (filter.searchQuery.isEmpty) return true;

      final query = filter.searchQuery.toLowerCase();
      return admin.name.toLowerCase().contains(query) ||
          admin.email.toLowerCase().contains(query) ||
          admin.phone.toLowerCase().contains(query);
    }).toList();
  });
});

class AdminStats {
  const AdminStats({
    required this.totalAdmins,
    required this.activeAdmins,
    required this.inactiveAdmins,
  });

  final int totalAdmins;
  final int activeAdmins;
  final int inactiveAdmins;
}

/// Computes summary statistics for visible Admins.
final adminStatsProvider = Provider<AsyncValue<AdminStats>>((ref) {
  final asyncAdmins = ref.watch(visibleAdminsProvider);

  return asyncAdmins.whenData((admins) {
    final active = admins.where((a) => a.isActive).length;
    return AdminStats(
      totalAdmins: admins.length,
      activeAdmins: active,
      inactiveAdmins: admins.length - active,
    );
  });
});
