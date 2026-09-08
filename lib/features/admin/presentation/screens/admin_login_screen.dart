import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/admin_auth_provider.dart';

/// Screen allowing Superadmin and sub-administrators to sign in.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController =
      TextEditingController(text: SuperAdminConfig.email);
  final _passwordController =
      TextEditingController(text: SuperAdminConfig.password);
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(adminAuthProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

    if (success && mounted) {
      final currentAdmin = ref.read(currentAdminUserProvider);
      if (currentAdmin != null && currentAdmin.mustResetPassword) {
        context.go(RouteNames.adminResetPassword);
      } else {
        context.go(RouteNames.adminDashboard);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthProvider);
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
      title: 'Administrator Login',
      showBackButton: false,
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
                  // Portal Badge Icon
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
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: isCompact ? 36 : 44,
                      ),
                    ),
                  ),

                  SizedBox(height: isCompact ? 14 : 18),

                  Text(
                    'Admin & Super Admin Portal',
                    style: (isCompact
                            ? theme.textTheme.titleLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Sign in with your Super Admin or Admin credentials',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      fontSize: isCompact ? 12 : 13,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isCompact ? 16 : 22),

                  // Superadmin Master Credentials Quick Pill
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: AppColors.primary.withAlpha(35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.key_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'SUPERADMIN MASTER CREDENTIALS',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _emailController.text = SuperAdminConfig.email;
                                _passwordController.text =
                                    SuperAdminConfig.password;
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Text(
                                  'Autofill',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Email: ${SuperAdminConfig.email}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Password: ${SuperAdminConfig.password}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Login Form Card
                  AppCard(
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Address',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Enter admin email'
                              : null,
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'Password',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'Password',
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Enter password'
                              : null,
                        ),

                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight.withAlpha(40),
                              borderRadius: AppRadius.smAll,
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        AppButton.primary(
                          label: 'Sign In to Portal',
                          icon: Icons.login_rounded,
                          isLoading: authState.isLoading,
                          onPressed: _submit,
                        ),
                      ],
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
}
