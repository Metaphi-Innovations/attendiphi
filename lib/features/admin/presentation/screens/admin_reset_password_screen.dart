import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/admin_auth_provider.dart';

/// Screen requiring newly created sub-administrators to set a permanent password
/// upon their first login before gaining access to the admin portal.
class AdminResetPasswordScreen extends ConsumerStatefulWidget {
  const AdminResetPasswordScreen({super.key});

  @override
  ConsumerState<AdminResetPasswordScreen> createState() =>
      _AdminResetPasswordScreenState();
}

class _AdminResetPasswordScreenState
    extends ConsumerState<AdminResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newPasswordController.text.length >= 8;
  bool get _hasNumberOrSpecial =>
      RegExp('[0-9!@#%^&*(),.?":{}|<>]').hasMatch(_newPasswordController.text);

  Future<void> _handlePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(adminAuthProvider.notifier)
        .resetPassword(newPassword: _newPasswordController.text.trim());

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password updated successfully! Welcome to the Admin Portal.',
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go(RouteNames.adminDashboard);
      } else {
        final error =
            ref.read(adminAuthProvider).errorMessage ?? 'Failed to update password.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(adminAuthProvider.notifier).signOut();
    if (mounted) {
      context.go(RouteNames.adminLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = ref.watch(currentAdminUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = context.isCompactMobile;

    final horizontalPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    return AppScaffold(
      title: 'Create Permanent Password',
      showBackButton: false,
      actions: [
        TextButton.icon(
          onPressed: _handleSignOut,
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Sign Out'),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: isCompact ? 16 : 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveBreakpoints.maxCardWidth,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lock Icon
                  Center(
                    child: Container(
                      padding: EdgeInsets.all(isCompact ? 16 : 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(60),
                            blurRadius: 18,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: Colors.white,
                        size: isCompact ? 36 : 44,
                      ),
                    ),
                  ),

                  SizedBox(height: isCompact ? 14 : 18),

                  Text(
                    'Set Your Permanent Password',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppColors.onSurfaceLight,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'This is your first login. For account security, please create a new permanent password to access the portal.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceVariantDark
                          : AppColors.onSurfaceVariantLight,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Admin Profile Info Card
                  if (currentAdmin != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                AppColors.primary.withAlpha(30),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentAdmin.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  currentAdmin.email,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'First Login',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  AppCard(
                    padding: EdgeInsets.all(isCompact ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // New Password Field
                        AppTextField(
                          controller: _newPasswordController,
                          label: 'New Password',
                          hint: 'Enter new permanent password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          obscureText: _obscureNewPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a new password';
                            }
                            if (value.trim().length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Confirm Password Field
                        AppTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm New Password',
                          hint: 'Re-enter your new password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please confirm your new password';
                            }
                            if (value.trim() !=
                                _newPasswordController.text.trim()) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password Strength Criteria Checklist
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Password Requirements:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildCriteriaRow(
                                'At least 8 characters long',
                                _hasMinLength,
                              ),
                              const SizedBox(height: 4),
                              _buildCriteriaRow(
                                'Contains numbers or special characters',
                                _hasNumberOrSpecial,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Submit Button
                        AppButton(
                          label: 'Save Password & Enter Portal',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting ? null : _handlePasswordReset,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cancel / Sign Out Footer
                  Center(
                    child: TextButton.icon(
                      onPressed: _handleSignOut,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back to Login'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaRow(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: met ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: met ? const Color(0xFF10B981) : const Color(0xFF64748B),
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
