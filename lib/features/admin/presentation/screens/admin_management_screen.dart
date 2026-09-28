import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_url.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../data/datasources/admin_auth_email.dart';
import '../../domain/entities/admin_user.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_management_provider.dart';

/// Screen allowing the Super Admin to create, view, and manage sub-administrators.
class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _generateSecurePassword() {
    const chars =
        'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789!@#%^&*';
    final rnd = Random.secure();
    return List.generate(10, (i) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _showCreateAdminDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController(
      text: _generateSecurePassword(),
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool obscurePassword = false;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final screenWidth = MediaQuery.of(dialogCtx).size.width;
          final isMobile = screenWidth < 600;

          final fieldBgColor = isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF8FAFC);
          final defaultBorderColor = isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0);

          InputDecoration buildFieldDecoration({
            required String hint,
            required Widget prefixIcon,
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: fieldBgColor,
              // Hide Flutter's default "0/100" maxLength counter.
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: defaultBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: defaultBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.94 : 500,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create New Admin',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'You can email login credentials after the account is created',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Full Name
                      const Text(
                        'Full Name *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. Rahul Sharma',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 18,
                          ),
                        ),
                        validator: Validators.validateName,
                        maxLength: AppConstants.nameMaxLength,
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      const Text(
                        'Phone Number *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. 9876543210',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 18,
                          ),
                        ),
                        validator: Validators.validatePhone,
                        maxLength: 15,
                      ),
                      const SizedBox(height: 14),

                      // Email Address
                      const Text(
                        'Email Address * (Credentials will be sent here)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. rahul.sharma@example.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 18,
                          ),
                        ),
                        validator: Validators.validateEmail,
                        maxLength: 320,
                      ),
                      const SizedBox(height: 14),

                      // Generated / Custom Password
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Login Password *',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                passwordController.text =
                                    _generateSecurePassword();
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 14),
                            label: const Text(
                              'Regenerate',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: buildFieldDecoration(
                          hint: 'Enter or auto-generate password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setDialogState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter a password';
                          }
                          if (val.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Notice Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF10B981).withAlpha(40),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.mark_email_read_rounded,
                              size: 18,
                              color: Color(0xFF10B981),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'After you create this Admin, Send Mail emails the login details through Attendiphi mail.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF047857),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        setDialogState(
                                          () => isSubmitting = true,
                                        );
                                        final name = nameController.text.trim();
                                        final phone = phoneController.text
                                            .trim();
                                        final email = emailController.text
                                            .trim();
                                        final password = passwordController.text
                                            .trim();

                                        try {
                                          final currentAdmin = ref.read(
                                            currentAdminUserProvider,
                                          );
                                          final repo = ref.read(
                                            adminRepositoryProvider,
                                          );

                                          final createdByValue =
                                              currentAdmin?.id ?? '';

                                          final createdAdmin = await repo
                                              .createAdmin(
                                                name: name,
                                                phone: phone,
                                                email: email,
                                                password: password,
                                                createdBy: createdByValue,
                                                role: AdminRole.admin,
                                              );

                                          // Refresh list from Firestore stream.
                                          ref.invalidate(allAdminsStreamProvider);

                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                          }

                                          if (mounted) {
                                            _showCredentialSuccessDialog(
                                              createdAdmin,
                                              password,
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(
                                            () => isSubmitting = false,
                                          );
                                          if (mounted) {
                                            final message =
                                                AdminAuthEmailClient
                                                    .publicCreateError(e);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(message),
                                                backgroundColor:
                                                    AppColors.error,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Create Admin',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCredentialSuccessDialog(
    AdminUser admin,
    String password,
  ) async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminCredentialsMailDialog(
        admin: admin,
        password: password,
      ),
    );
    if (!mounted || sent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email sent successfully to ${admin.email}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditAdminDialog(AdminUser admin) {
    final nameController = TextEditingController(text: admin.name);
    final phoneController = TextEditingController(text: admin.phone);
    final emailController = TextEditingController(text: admin.email);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    bool isActive = admin.isActive;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          final screenWidth = MediaQuery.of(dialogCtx).size.width;
          final isMobile = screenWidth < 600;

          final fieldBgColor = isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF8FAFC);
          final defaultBorderColor = isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0);

          InputDecoration buildFieldDecoration({
            required String hint,
            required Widget prefixIcon,
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13.5,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: fieldBgColor,
              // Hide Flutter's default "0/100" maxLength counter.
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: defaultBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: defaultBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.94 : 500,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Admin Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Update administrator profile and status',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Full Name
                      const Text(
                        'Full Name *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. Rahul Sharma',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            size: 18,
                          ),
                        ),
                        validator: Validators.validateName,
                        maxLength: AppConstants.nameMaxLength,
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      const Text(
                        'Phone Number *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. 9876543210',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 18,
                          ),
                        ),
                        validator: Validators.validatePhone,
                        maxLength: 15,
                      ),
                      const SizedBox(height: 14),

                      // Email Address
                      const Text(
                        'Email Address *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. rahul.sharma@example.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            size: 18,
                          ),
                        ),
                        validator: Validators.validateEmail,
                        maxLength: 320,
                      ),
                      const SizedBox(height: 14),

                      // Account Status Switch
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: fieldBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: defaultBorderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Account Status',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  isActive
                                      ? 'Active (Full system access)'
                                      : 'Inactive (Login restricted)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isActive
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: isActive,
                              activeTrackColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setDialogState(() => isActive = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        setDialogState(
                                          () => isSubmitting = true,
                                        );
                                        final name = nameController.text.trim();
                                        final phone = phoneController.text
                                            .trim();
                                        final email = emailController.text
                                            .trim();

                                        try {
                                          final updated = admin.copyWith(
                                            name: name,
                                            phone: phone,
                                            email: email,
                                            isActive: isActive,
                                          );

                                          await ref
                                              .read(adminRepositoryProvider)
                                              .updateAdmin(updated);

                                          if (ctx.mounted) {
                                            Navigator.pop(ctx);
                                          }

                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Admin "$name" updated successfully!',
                                                ),
                                                backgroundColor: const Color(
                                                  0xFF10B981,
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(
                                            () => isSubmitting = false,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor:
                                                    AppColors.error,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      AppColors.primary,
      const Color(0xFF0284C7),
      const Color(0xFF0D9488),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFFE11D48),
      const Color(0xFF059669),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnits.reduce((a, b) => a + b) % colors.length];
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.trim().substring(0, min(2, name.trim().length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = context.isMobile;
    final adminsAsync = ref.watch(filteredAdminsProvider);
    final filterState = ref.watch(adminFilterProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 16 : 20,
          isMobile ? 16 : 24,
          isMobile ? 16 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Section
            if (!isMobile)
              AppPageHeader(
                title: 'Admin Management',
                actions: [
                  FilledButton.icon(
                    onPressed: _showCreateAdminDialog,
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Create Admin'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.mdAll,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showCreateAdminDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text(
                        'Create Admin',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.mdAll,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 2. Search Bar / Toolbar (Always visually present for layout consistency across screens)
            _buildToolbar(context, theme, isDark, filterState),
            const SizedBox(height: 16),

            // 3. Admins List Table
            Expanded(
              child: adminsAsync.when(
                data: (admins) {
                  if (admins.isEmpty) {
                    return AppCard(
                      child: AppEmptyView(
                        icon: Icons.admin_panel_settings_outlined,
                        message: filterState.searchQuery.isNotEmpty
                            ? 'No admins match "${filterState.searchQuery}".'
                            : 'No sub-administrators created yet.',
                        actionLabel: filterState.searchQuery.isNotEmpty
                            ? 'Clear Search'
                            : 'Create First Admin',
                        action: filterState.searchQuery.isNotEmpty
                            ? () {
                                _searchController.clear();
                                ref
                                    .read(adminFilterProvider.notifier)
                                    .resetFilters();
                              }
                            : _showCreateAdminDialog,
                      ),
                    );
                  }

                  return isMobile
                      ? _buildMobileAdminList(context, theme, isDark, admins)
                      : _buildDesktopAdminTable(context, theme, isDark, admins);
                },
                loading: () => const AppCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 24.0,
                        horizontal: 16.0,
                      ),
                      child: MetaPhiLoadingIndicator(showCard: false),
                    ),
                  ),
                ),
                error: (err, _) => AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Error loading admins: $err'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AdminFilterState filterState,
  ) {
    final isMobile = context.isMobile;

    final searchInput = SizedBox(
      width: isMobile ? double.infinity : 260,
      height: 40,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search admin by name, email...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: filterState.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(adminFilterProvider.notifier).setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (val) {
          ref.read(adminFilterProvider.notifier).setSearchQuery(val);
        },
      ),
    );

    final statusDropdown = Container(
      height: 40,
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: filterState.statusFilter != AdminStatusFilter.all
              ? AppColors.primary
              : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AdminStatusFilter>(
          value: filterState.statusFilter,
          isExpanded: isMobile,
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: AdminStatusFilter.values.map((f) {
            return DropdownMenuItem(
              value: f,
              child: Text(
                f.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: filterState.statusFilter == f
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              ref.read(adminFilterProvider.notifier).setStatusFilter(val);
            }
          },
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : const Color(0xFFE2E8F0),
        ),
        boxShadow: AppShadows.sm,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: 8),
                statusDropdown,
              ],
            )
          : Row(
              children: [
                searchInput,
                const SizedBox(width: 12),
                statusDropdown,
              ],
            ),
    );
  }

  Widget _buildDesktopAdminTable(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<AdminUser> admins,
  ) {
    final borderColor = isDark
        ? AppColors.outlineDark
        : const Color(0xFFE2E8F0);
    const double headerHeight = 52.0;
    const double rowHeight = 56.0;

    // Shared flex ratios to guarantee ample room, equal alignment, and zero clashing:
    const int flexAdmin = 3;     // ADMIN (Avatar + Name + Role)
    const int flexEmail = 4;     // EMAIL (Long email addresses like omkaranarse.metaphi@gmail.com)
    const int flexPhone = 2;     // PHONE (Phone numbers)
    const int flexStatus = 1;    // STATUS (Active / Inactive badge)
    const int flexCreated = 2;   // CREATED ON (e.g. 07 Sep 2026)
    const int flexActions = 1;   // ACTIONS (3-dots icon)

    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 0.5,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minTableWidth =
            constraints.maxWidth < 950 ? 950.0 : constraints.maxWidth;
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        final tableContent = Container(
          width: minTableWidth,
          height: hasBoundedHeight ? constraints.maxHeight : null,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: borderColor),
            boxShadow: AppShadows.sm,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. Table Header
              Container(
                height: headerHeight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: flexAdmin,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text(
                          'ADMIN (${admins.length})',
                          style: headerStyle,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: flexEmail,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text('EMAIL', style: headerStyle),
                      ),
                    ),
                    Expanded(
                      flex: flexPhone,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text('PHONE', style: headerStyle),
                      ),
                    ),
                    Expanded(
                      flex: flexStatus,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text('STATUS', style: headerStyle),
                      ),
                    ),
                    Expanded(
                      flex: flexCreated,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text('CREATED ON', style: headerStyle),
                      ),
                    ),
                    Expanded(
                      flex: flexActions,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('ACTIONS', style: headerStyle),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Table Rows
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: admins.length,
                  separatorBuilder: (context, index) => const SizedBox.shrink(),
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    final avatarColor = _getAvatarColor(admin.name);
                    final initials = _getInitials(admin.name);
                    final createdStr = admin.createdAt != null
                        ? DateFormat('dd MMM yyyy').format(admin.createdAt!)
                        : '—';
                    final isEven = index % 2 == 0;
                    final rowBg = isEven
                        ? Colors.transparent
                        : (isDark
                            ? const Color(0xFF1E293B).withAlpha(50)
                            : const Color(0xFFF8FAFC));

                    return Container(
                      height: rowHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: rowBg,
                        border: Border(
                          bottom: BorderSide(color: borderColor.withAlpha(60)),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Column 1: ADMIN
                          Expanded(
                            flex: flexAdmin,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: avatarColor.withAlpha(30),
                                      borderRadius: AppRadius.xsAll,
                                      border: Border.all(
                                        color: avatarColor.withAlpha(70),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: avatarColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          admin.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          admin.role.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Column 2: EMAIL
                          Expanded(
                            flex: flexEmail,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: SelectableText(
                                admin.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? const Color(0xFFE2E8F0)
                                      : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),

                          // Column 3: PHONE
                          Expanded(
                            flex: flexPhone,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: SelectableText(
                                admin.phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),

                          // Column 4: STATUS
                          Expanded(
                            flex: flexStatus,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: AppBadge(
                                  label: admin.isActive ? 'Active' : 'Inactive',
                                  variant: admin.isActive
                                      ? AppBadgeVariant.success
                                      : AppBadgeVariant.error,
                                ),
                              ),
                            ),
                          ),

                          // Column 5: CREATED ON
                          Expanded(
                            flex: flexCreated,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Text(
                                createdStr,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),

                          // Column 6: ACTIONS
                          Expanded(
                            flex: flexActions,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert_rounded,
                                  size: 19,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                                tooltip: 'Admin Actions',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showEditAdminDialog(admin);
                                  } else if (val == 'resend') {
                                    _resendCredentials(admin);
                                  } else if (val == 'toggle') {
                                    _toggleAdminStatus(admin);
                                  } else if (val == 'delete') {
                                    _confirmDeleteAdmin(admin);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Edit Details',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'resend',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.email_outlined,
                                          size: 17,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Resend Credentials',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Row(
                                      children: [
                                        Icon(
                                          admin.isActive
                                              ? Icons.block_outlined
                                              : Icons.check_circle_outline,
                                          size: 17,
                                          color: admin.isActive
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          admin.isActive
                                              ? 'Deactivate Admin'
                                              : 'Activate Admin',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: admin.isActive
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(height: 1),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          size: 17,
                                          color: Color(0xFFEF4444),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Delete Admin',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth < 950) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tableContent,
            ),
          );
        }

        return tableContent;
      },
    );
  }

  Widget _buildMobileAdminList(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<AdminUser> admins,
  ) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: admins.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final admin = admins[index];
        final avatarColor = _getAvatarColor(admin.name);
        final initials = _getInitials(admin.name);
        final createdStr = admin.createdAt != null
            ? DateFormat('dd MMM yyyy').format(admin.createdAt!)
            : '—';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(
              color: isDark ? AppColors.outlineDark : const Color(0xFFE2E8F0),
            ),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: avatarColor.withAlpha(30),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: avatarColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        Text(
                          admin.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: admin.isActive ? 'Active' : 'Inactive',
                    variant: admin.isActive
                        ? AppBadgeVariant.success
                        : AppBadgeVariant.error,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(admin.phone, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  Text(
                    'Added: $createdStr',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.more_horiz_rounded,
                          size: 19,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    tooltip: 'Admin actions',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditAdminDialog(admin);
                      } else if (val == 'resend') {
                        _resendCredentials(admin);
                      } else if (val == 'toggle') {
                        _toggleAdminStatus(admin);
                      } else if (val == 'delete') {
                        _confirmDeleteAdmin(admin);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Edit Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'resend',
                        child: Row(
                          children: [
                            Icon(
                              Icons.send_rounded,
                              size: 17,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Resend Credentials',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              admin.isActive
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 17,
                              color: admin.isActive
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              admin.isActive
                                  ? 'Deactivate Admin'
                                  : 'Activate Admin',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: admin.isActive
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                              color: Color(0xFFEF4444),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete Admin',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleAdminStatus(AdminUser admin) async {
    final newStatus = !admin.isActive;
    try {
      await ref
          .read(adminRepositoryProvider)
          .toggleAdminActive(admin.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${admin.name} ${newStatus ? 'activated' : 'deactivated'} successfully.',
            ),
            backgroundColor: newStatus
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resendCredentials(AdminUser admin) async {
    final password = admin.plainPassword.trim();
    if (password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The original password is not stored. Ask this admin to use Forgot Password for a Firebase reset email.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    _showCredentialSuccessDialog(admin, password);
  }

  Future<void> _confirmDeleteAdmin(AdminUser admin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Admin Account?'),
        content: Text(
          'Are you sure you want to delete "${admin.name}" (${admin.email})? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(adminRepositoryProvider).deleteAdmin(
          admin.id,
          email: admin.email,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted admin "${admin.name}" from database and Firebase Authentication.',
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting admin: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

enum _MailSendUi { idle, authorizing, sending, sent, error }

/// Post-create modal: copy credentials or send them via SMTP Edge Function.
class AdminCredentialsMailDialog extends ConsumerStatefulWidget {
  const AdminCredentialsMailDialog({
    super.key,
    required this.admin,
    required this.password,
  });

  final AdminUser admin;
  final String password;

  @override
  ConsumerState<AdminCredentialsMailDialog> createState() =>
      _AdminCredentialsMailDialogState();
}

class _AdminCredentialsMailDialogState
    extends ConsumerState<AdminCredentialsMailDialog> {
  late final String _idempotencyKey;
  _MailSendUi _state = _MailSendUi.idle;
  String _errorMessage = '';
  bool _copied = false;
  bool _sendInFlight = false;
  Timer? _copiedResetTimer;

  @override
  void initState() {
    super.initState();
    _idempotencyKey =
        'cred-${widget.admin.id}-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  String? _senderSecret(AdminAuthState auth) {
    final fromSession = (auth.sessionPassword ?? '').trim();
    if (fromSession.isNotEmpty) return fromSession;
    return null;
  }

  Future<void> _sendMail() async {
    if (_sendInFlight ||
        _state == _MailSendUi.authorizing ||
        _state == _MailSendUi.sending) {
      return;
    }
    final auth = ref.read(adminAuthProvider);
    final sender = auth.currentAdmin;
    if (sender == null || !auth.isAuthenticated) {
      setState(() {
        _state = _MailSendUi.error;
        _errorMessage = '⚠ Email could not be sent.\nPlease try again.';
      });
      return;
    }

    _sendInFlight = true;
    setState(() {
      _state = _MailSendUi.sending;
      _errorMessage = '';
    });
    AppLogger.info(
      'SEND MAIL START recipient: ${widget.admin.email}',
      tag: 'AdminCredentialsMail',
    );

    final result = await ref.read(adminRepositoryProvider).sendCredentials(
          admin: widget.admin,
          password: widget.password,
          senderEmail: sender.email,
          senderPassword: _senderSecret(auth) ?? '',
          idempotencyKey: _idempotencyKey,
          onProgress: (phase) {
            if (!mounted) return;
            setState(() {
              _state = _MailSendUi.sending;
            });
          },
        );

    if (!mounted) return;
    if (result.success) {
      AppLogger.info(
        'SEND MAIL SUCCESS recipient: ${widget.admin.email}',
        tag: 'AdminCredentialsMail',
      );
      _sendInFlight = false;
      Navigator.of(context).pop(true);
      return;
    } else {
      AppLogger.warning(
        'SEND MAIL FAILURE recipient: ${widget.admin.email}',
        tag: 'AdminCredentialsMail',
      );
      _sendInFlight = false;
      setState(() {
        _state = _MailSendUi.error;
        final message = result.userMessage.trim();
        _errorMessage = message.isEmpty
            ? '⚠ Email could not be sent.\nPlease try again.'
            : (message.startsWith('⚠') ? message : '⚠ $message');
      });
    }
  }

  void _copyCredentials() {
    final text = '''
QR Check-in Portal — Admin
Portal URL: ${AppUrl.portalOrigin}/
Name: ${widget.admin.name}
Email: ${widget.admin.email}
Phone: ${widget.admin.phone}
Role: ${widget.admin.role.label}
Password: ${widget.password}
''';
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    _copiedResetTimer?.cancel();
    _copiedResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  Widget _statusBanner() {
    if (_state == _MailSendUi.sent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email sent successfully to ${widget.admin.email}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Sent from Attendiphi mail.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF059669),
              ),
            ),
          ],
        ),
      );
    }
    if (_state == _MailSendUi.error) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withAlpha(18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withAlpha(50)),
        ),
        child: Text(
          _errorMessage,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB91C1C),
          ),
        ),
      );
    }
    if (_state == _MailSendUi.authorizing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withAlpha(50)),
        ),
        child: const Text(
          'Sending email...',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Text(
        'Send login credentials to:\n${widget.admin.email}',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _copyButton() {
    final busy =
        _state == _MailSendUi.sending || _state == _MailSendUi.authorizing;
    return OutlinedButton.icon(
      onPressed: busy ? null : _copyCredentials,
      icon: Icon(
        _copied ? Icons.check_rounded : Icons.copy_rounded,
        size: 16,
      ),
      label: Text(_copied ? 'Credentials copied' : 'Copy Credentials'),
    );
  }

  Widget _mailButton() {
    final busy =
        _state == _MailSendUi.sending || _state == _MailSendUi.authorizing;
    final label = _state == _MailSendUi.authorizing
        ? 'Sending...'
        : _state == _MailSendUi.sending
            ? 'Sending...'
            : _state == _MailSendUi.sent
                ? 'Email Sent'
                : 'Send Mail';
    return FilledButton.icon(
      onPressed: busy ? null : _sendMail,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              _state == _MailSendUi.sent
                  ? Icons.check_rounded
                  : Icons.mail_outline_rounded,
              size: 16,
            ),
      label: Text(label),
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: _state != _MailSendUi.sending &&
          _state != _MailSendUi.authorizing,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0x3322C55E),
              child: Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 22,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Admin Created Successfully!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBanner(),
            if (_copied && _state != _MailSendUi.authorizing && _state != _MailSendUi.sending) ...[
              const SizedBox(height: 8),
              const Text(
                '✓ Credentials copied',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _credentialLine('Name', widget.admin.name),
                  const SizedBox(height: 6),
                  _credentialLine('Email (ID)', widget.admin.email),
                  const SizedBox(height: 6),
                  _credentialLine('Phone', widget.admin.phone),
                  const SizedBox(height: 6),
                  _credentialLine('Role', widget.admin.role.label),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _copyButton()),
                const SizedBox(width: 8),
                Expanded(child: _mailButton()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _credentialLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

