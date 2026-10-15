import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/admin_auth_provider.dart';

class AdminForgotPasswordScreen extends ConsumerStatefulWidget {
  const AdminForgotPasswordScreen({super.key});

  @override
  ConsumerState<AdminForgotPasswordScreen> createState() =>
      _AdminForgotPasswordScreenState();
}

class _AdminForgotPasswordScreenState
    extends ConsumerState<AdminForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  String? _errorMessage;
  DateTime? _lastSubmitAt;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending || _sent) return;
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    if (_lastSubmitAt != null &&
        now.difference(_lastSubmitAt!) < const Duration(seconds: 8)) {
      return;
    }
    _lastSubmitAt = now;

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(adminPasswordResetServiceProvider)
        .requestReset(email: _emailController.text.trim());

    if (!mounted) return;
    setState(() {
      _isSending = false;
      if (result.accepted) {
        _sent = true;
      } else {
        _errorMessage = result.userMessage;
      }
    });
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

    return AppScaffold(
      title: 'Forgot Password',
      showBackButton: false,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isCompact ? 32 : 56,
            horizontalPadding,
            isCompact ? 16 : 32,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveBreakpoints.maxCardWidth,
            ),
            child: _sent
                ? _buildSuccess(
                    theme,
                    isDark,
                    isCompact ? 88.0 : 110.0,
                    isCompact ? 20.0 : 28.0,
                  )
                : _buildForm(
                    theme,
                    isDark,
                    isCompact ? 88.0 : 110.0,
                    isCompact ? 20.0 : 28.0,
                  ),
          ),
        ),
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
          Center(
            child: Image.asset(
              'assets/images/attendiphi_logo.png',
              height: logoHeight,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: logoToCard),
          AppCard(
            elevation: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forgot Password?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter your registered email address and we'll send you a password reset link.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
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
                  enabled: !_isSending,
                  prefixIcon: const Icon(Icons.email_outlined),
                  validator: Validators.validateEmail,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withAlpha(40),
                      borderRadius: AppRadius.smAll,
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                AppButton.primary(
                  label: 'Send Reset Link',
                  icon: Icons.mark_email_unread_outlined,
                  isLoading: _isSending,
                  enabled: !_isSending,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _isSending
                  ? null
                  : () => context.go(RouteNames.adminLogin),
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

  Widget _buildSuccess(
    ThemeData theme,
    bool isDark,
    double logoHeight,
    double logoToCard,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/images/attendiphi_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(height: logoToCard),
        AppCard(
          elevation: 3,
          child: Column(
            children: [
              const Icon(
                Icons.mark_email_read_rounded,
                color: Color(0xFF10B981),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                '✓ Check your email',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "If an account exists for this email address, we've sent a password reset link.\n\nThe link will expire after a limited period.",
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
                label: 'Back to Login',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.go(RouteNames.adminLogin),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
