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
import '../../data/datasources/admin_password_reset_service.dart';
import '../../domain/admin_password_hasher.dart';
import '../providers/admin_auth_provider.dart';

class AdminForgotPasswordResetScreen extends ConsumerStatefulWidget {
  const AdminForgotPasswordResetScreen({
    super.key,
    this.token,
    this.oobCode,
    this.mode,
  });

  final String? token;
  final String? oobCode;
  final String? mode;

  @override
  ConsumerState<AdminForgotPasswordResetScreen> createState() =>
      _AdminForgotPasswordResetScreenState();
}

class _AdminForgotPasswordResetScreenState
    extends ConsumerState<AdminForgotPasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _checkingToken = true;
  bool _tokenValid = false;
  bool _isSubmitting = false;
  bool _success = false;
  String? _errorMessage;
  String? _accountEmail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyToken());
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyToken() async {
    final mode = (widget.mode ?? '').trim();
    final oobCode = (widget.oobCode ?? '').trim();
    final token = (widget.token ?? '').trim();
    final code = oobCode.isNotEmpty ? oobCode : token;
    final isPasswordReset =
        code.isNotEmpty && (mode.isEmpty || mode == 'resetPassword');
    if (!isPasswordReset) {
      setState(() {
        _checkingToken = false;
        _tokenValid = false;
      });
      return;
    }

    final status = await ref
        .read(adminPasswordResetServiceProvider)
        .verifyToken(code);
    if (!mounted) return;
    setState(() {
      _checkingToken = false;
      _tokenValid = status.valid;
      if (status.email.isNotEmpty) {
        _accountEmail = status.email;
      }
    });
  }

  bool get _hasMinLength =>
      _newPasswordController.text.trim().length >= AdminPasswordHasher.minLength;
  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text.trim() ==
          _confirmPasswordController.text.trim();
  bool get _hasComplexity =>
      AdminPasswordHasher.hasComplexity(_newPasswordController.text);

  Future<void> _submit() async {
    if (_isSubmitting || !_tokenValid) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    PasswordResetCompleteResult result;
    final oobCode = (widget.oobCode ?? '').trim();
    final token = (widget.token ?? '').trim();
    final resetCode = oobCode.isNotEmpty ? oobCode : token;
    result = await ref.read(adminPasswordResetServiceProvider).completeReset(
          token: resetCode,
          newPassword: _newPasswordController.text.trim(),
        );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (result.success) {
        _success = true;
      } else if (result.invalidOrExpired) {
        _tokenValid = false;
      } else {
        _errorMessage = result.userMessage;
      }
    });
  }

  Future<void> _navigateToLogin() async {
    try {
      await ref.read(adminAuthProvider.notifier).signOut();
    } catch (_) {}
    if (mounted) {
      context.go(RouteNames.adminLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = context.isCompactMobile;
    final horizontalPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
    final logoHeight = isCompact ? 88.0 : 110.0;
    final logoToCard = isCompact ? 20.0 : 28.0;

    return AppScaffold(
      title: 'Reset Password',
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
            child: _checkingToken
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/attendiphi_logo.png',
                          height: logoHeight,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 28),
                        const CircularProgressIndicator(),
                      ],
                    ),
                  )
                : _success
                    ? _buildSuccess(theme, isDark, logoHeight, logoToCard)
                    : !_tokenValid
                        ? _buildExpired(theme, isDark, logoHeight, logoToCard)
                        : _buildForm(theme, isDark, logoHeight, logoToCard),
          ),
        ),
      ),
    );
  }

  Widget _logo(double height) {
    return Center(
      child: Image.asset(
        'assets/images/attendiphi_logo.png',
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildForm(
    ThemeData theme,
    bool isDark,
    double logoHeight,
    double logoToCard,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _logo(logoHeight),
          SizedBox(height: logoToCard),
          AppCard(
            elevation: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset Password',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new password to continue to the Admin Portal.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                if (_accountEmail != null && _accountEmail!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _accountEmail!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'New Password',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  label: 'New Password',
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: AdminPasswordHasher.policyError,
                ),
                const SizedBox(height: 18),
                Text(
                  'Confirm Password',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (value.trim() != _newPasswordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _passwordRequirements(isDark),
                if (_errorMessage != null) ...[
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
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
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
                  label: 'Reset Password',
                  icon: Icons.lock_reset_rounded,
                  isLoading: _isSubmitting,
                  enabled: !_isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _isSubmitting ? null : _navigateToLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Back to Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordRequirements(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          _requirement('Minimum 8 characters', _hasMinLength),
          const SizedBox(height: 4),
          _requirement(
            'Contains a number or special character',
            _hasComplexity,
          ),
          const SizedBox(height: 4),
          _requirement('Passwords must match', _passwordsMatch),
        ],
      ),
    );
  }

  Widget _buildSuccess(
    ThemeData theme,
    bool isDark,
    double logoHeight,
    double logoToCard,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logo(logoHeight),
        SizedBox(height: logoToCard),
        AppCard(
          elevation: 3,
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '✓ Password Reset Successfully',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your administrator password has been updated.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              AppButton.primary(
                label: 'Sign In to Portal',
                icon: Icons.login_rounded,
                onPressed: _navigateToLogin,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpired(
    ThemeData theme,
    bool isDark,
    double logoHeight,
    double logoToCard,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _logo(logoHeight),
        SizedBox(height: logoToCard),
        AppCard(
          elevation: 3,
          child: Column(
            children: [
              const Icon(
                Icons.link_off_rounded,
                color: AppColors.error,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                'Reset Link Expired',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This password reset link is no longer valid.\nPlease request a new password reset link.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              AppButton.primary(
                label: 'Request New Link',
                icon: Icons.mark_email_unread_outlined,
                onPressed: () => context.go(RouteNames.adminForgotPassword),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: _navigateToLogin,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Back to Login'),
          ),
        ),
      ],
    );
  }

  Widget _requirement(String label, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 15,
          color: met ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? const Color(0xFF047857) : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
