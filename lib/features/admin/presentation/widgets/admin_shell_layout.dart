import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../providers/admin_auth_provider.dart';
import 'admin_inspection_banner.dart';

/// Persistent Admin Shell with a permanent left sidebar (desktop/tablet)
/// and adaptive drawer (mobile).
///
/// Tab switches use [StatefulNavigationShell.goBranch] without a full-screen
/// loader so the indexed stack can show the already-mounted branch instantly.
class AdminShellLayout extends ConsumerStatefulWidget {
  const AdminShellLayout({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AdminShellLayout> createState() => _AdminShellLayoutState();
}

class _AdminShellLayoutState extends ConsumerState<AdminShellLayout> {
  int get currentTab => widget.navigationShell.currentIndex;

  void _onItemTapped(
    BuildContext context,
    int index, {
    required bool isMobile,
  }) {
    if (isMobile) {
      Navigator.of(context, rootNavigator: false).pop();
    }
    final current = widget.navigationShell.currentIndex;
    if (index == current) {
      // Re-tap active tab → reset nested stacks (e.g. substitute detail → list).
      widget.navigationShell.goBranch(index, initialLocation: true);
    } else {
      // Switch tabs → restore prior branch state for instant return.
      widget.navigationShell.goBranch(index, initialLocation: false);
    }
  }

  String _getTabTitle(int tab) {
    switch (tab) {
      case 0:
        return 'Daily Attendance';
      case 1:
        return 'Attendance Overview';
      case 2:
        return 'Visitors Records';
      case 3:
        return 'Member Management';
      case 4:
        return 'Substitutes';
      case 5:
        return 'Venue QR Standee';
      case 6:
        return 'Admin Management';
      default:
        return 'Admin Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = context.screenWidth;
    final showSidebar = screenWidth >= 768;

    if (!showSidebar) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            _getTabTitle(currentTab),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        drawer: Drawer(
          child: SafeArea(
            bottom: false,
            child: _buildSidebarContent(context, isMobile: true),
          ),
        ),
        body: Column(
          children: [
            const AdminInspectionBanner(),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    }

    final sidebarWidth = screenWidth < 1024 ? 220.0 : 250.0;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: sidebarWidth,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: _buildSidebarContent(context, isMobile: false),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const AdminInspectionBanner(),
                Expanded(child: widget.navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, {required bool isMobile}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Only rebuild sidebar chrome when display identity changes — not on every
    // auth session tick (token refresh, sessionResolved, etc.).
    final identity = ref.watch(
      currentAdminUserProvider.select(
        (admin) => (
          name: admin?.name ?? 'Administrator',
          roleLabel: admin?.role.label ?? 'Admin',
        ),
      ),
    );

    final adminName = identity.name;
    final adminRoleLabel = identity.roleLabel;
    final initials = adminName.trim().isNotEmpty
        ? (adminName.trim().split(' ').length > 1
              ? '${adminName.trim().split(' ')[0][0]}${adminName.trim().split(' ')[1][0]}'
              : adminName.substring(0, 1))
        : 'A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, isMobile ? 18 : 24, 16, 16),
          child: Center(
            child: Image.asset(
              'assets/images/attendiphi_logo.png',
              height: isMobile ? 76 : 88,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),

        const SizedBox(height: 8),

        _SidebarNavItem(
          icon: Icons.dashboard_rounded,
          label: 'Daily Attendance',
          isSelected: currentTab == 0,
          onTap: () => _onItemTapped(context, 0, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.table_chart_rounded,
          label: 'Attendance Overview',
          isSelected: currentTab == 1,
          onTap: () => _onItemTapped(context, 1, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.badge_rounded,
          label: 'Visitors',
          isSelected: currentTab == 2,
          onTap: () => _onItemTapped(context, 2, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.people_rounded,
          label: 'Members',
          isSelected: currentTab == 3,
          onTap: () => _onItemTapped(context, 3, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.person_search_rounded,
          label: 'Substitutes',
          isSelected: currentTab == 4,
          onTap: () => _onItemTapped(context, 4, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.qr_code_2_rounded,
          label: 'QR Standee',
          isSelected: currentTab == 5,
          onTap: () => _onItemTapped(context, 5, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.supervisor_account_rounded,
          label: 'Admins',
          isSelected: currentTab == 6,
          onTap: () => _onItemTapped(context, 6, isMobile: isMobile),
        ),

        const Spacer(),
        Divider(
          height: 1,
          color: theme.dividerColor.withAlpha(isDark ? 40 : 25),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primary.withAlpha(25),
                    child: Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adminName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          adminRoleLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 15),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                      color: theme.dividerColor.withAlpha(isDark ? 50 : 35),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.smAll,
                    ),
                  ),
                  onPressed: () async {
                    await ref.read(adminAuthProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go(RouteNames.adminLogin);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppColors.primary;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected
            ? (isDark
                  ? AppColors.primary.withAlpha(45)
                  : AppColors.primaryContainer)
            : Colors.transparent,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.primaryLight : activeColor)
                        : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
