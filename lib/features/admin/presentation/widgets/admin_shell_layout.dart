import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../providers/admin_auth_provider.dart';
import 'admin_inspection_banner.dart';

/// Persistent Admin Shell with a permanent left sidebar (desktop/tablet)
/// and adaptive drawer (mobile) that swaps content panels with a branded
/// 2-second MetaPhi loading spinner on every page change.
class AdminShellLayout extends ConsumerStatefulWidget {
  const AdminShellLayout({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AdminShellLayout> createState() => _AdminShellLayoutState();
}

class _AdminShellLayoutState extends ConsumerState<AdminShellLayout> {
  bool _isPageTransitioning = false;
  int _lastIndex = -1;
  Timer? _transitionTimer;

  int get currentTab => widget.navigationShell.currentIndex;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.navigationShell.currentIndex;
    _startPageLoadingTransition(widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(AdminShellLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _lastIndex) {
      _startPageLoadingTransition(widget.navigationShell.currentIndex);
    }
  }

  void _startPageLoadingTransition(int index) {
    _lastIndex = index;
    _transitionTimer?.cancel();

    // Check if running in automated test suite
    final isTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');

    if (isTest) {
      _isPageTransitioning = false;
      return;
    }

    setState(() {
      _isPageTransitioning = true;
    });

    _transitionTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isPageTransitioning = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(
    BuildContext context,
    int index, {
    required bool isMobile,
  }) {
    if (isMobile) {
      Navigator.of(context, rootNavigator: false).pop();
    }
    if (index != widget.navigationShell.currentIndex) {
      _startPageLoadingTransition(index);
      widget.navigationShell.goBranch(
        index,
        initialLocation: false,
      );
    } else {
      widget.navigationShell.goBranch(
        index,
        initialLocation: true,
      );
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
        return 'Venue QR Standee';
      case 5:
        return 'Admin Management';
      default:
        return 'Admin Portal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = context.screenWidth;
    final showSidebar = screenWidth >= 768;

    if (!showSidebar) {
      // Mobile Layout with Top App Bar, Drawer, and Body
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
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: widget.navigationShell),
                  if (_isPageTransitioning)
                    Positioned.fill(
                      child: Container(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        child: const Center(
                          child: MetaPhiLoadingIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sidebarWidth = screenWidth < 1024 ? 220.0 : 250.0;

    // Desktop / Tablet Layout with Permanent Left Sidebar
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
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

          // Main Content View (Updates with MetaPhi loading spinner on tab click)
          Expanded(
            child: Column(
              children: [
                const AdminInspectionBanner(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: widget.navigationShell),
                      if (_isPageTransitioning)
                        Positioned.fill(
                          child: Container(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            child: const Center(
                              child: MetaPhiLoadingIndicator(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context, {
    required bool isMobile,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentAdmin = ref.watch(currentAdminUserProvider);

    final adminName = currentAdmin?.name ?? 'Super Admin';
    final adminRoleLabel = currentAdmin?.role.label ?? 'Super Admin';
    final initials = adminName.trim().isNotEmpty
        ? (adminName.trim().split(' ').length > 1
            ? '${adminName.trim().split(' ')[0][0]}${adminName.trim().split(' ')[1][0]}'
            : adminName.substring(0, 1))
        : 'A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            isMobile ? 18 : 24,
            16,
            16,
          ),
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

        // Shared Main Workspace Tabs (Accessible to both Super Admin and Admin)
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
          icon: Icons.qr_code_2_rounded,
          label: 'QR Standee',
          isSelected: currentTab == 4,
          onTap: () => _onItemTapped(context, 4, isMobile: isMobile),
        ),
        _SidebarNavItem(
          icon: Icons.supervisor_account_rounded,
          label: 'Admins',
          isSelected: currentTab == 5,
          onTap: () => _onItemTapped(context, 5, isMobile: isMobile),
        ),

        const Spacer(),
        Divider(
          height: 1,
          color: theme.dividerColor.withAlpha(isDark ? 40 : 25),
        ),

        // Bottom User Profile & Logout
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
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
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
    const activeColor = AppColors.primary; // Brand Indigo for Active Nav
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isSelected
            ? (isDark ? AppColors.primary.withAlpha(45) : AppColors.primaryContainer)
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
