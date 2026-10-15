import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../providers/attendance_overview_provider.dart';
import '../providers/visitor_management_provider.dart';
import '../widgets/searchable_thursday_date_dialog.dart';

class _CategoryBadgeStyle {
  const _CategoryBadgeStyle({
    required this.bg,
    required this.fg,
    required this.border,
  });

  final Color bg;
  final Color fg;
  final Color border;
}

/// Assigns consistent, distinguishable semantic colors to business categories with accessible contrast.
_CategoryBadgeStyle _getCategoryBadgeStyle(String category, bool isDark) {
  final norm = category.trim().toLowerCase();

  // 1. Healthcare & Diagnostics -> Emerald / Teal
  if (norm.contains('health') ||
      norm.contains('diagnost') ||
      norm.contains('medic') ||
      norm.contains('pharma')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF064E3B).withAlpha(140)
          : const Color(0xFFECFDF5),
      fg: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
      border: isDark
          ? const Color(0xFF059669).withAlpha(100)
          : const Color(0xFFA7F3D0),
    );
  }

  // 2. Hospitality & Event Catering -> Amber / Warm Gold
  if (norm.contains('hospit') ||
      norm.contains('cater') ||
      norm.contains('food') ||
      norm.contains('restaur')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF78350F).withAlpha(140)
          : const Color(0xFFFFFBEB),
      fg: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      border: isDark
          ? const Color(0xFFD97706).withAlpha(100)
          : const Color(0xFFFDE68A),
    );
  }

  // 3. Real Estate & Infrastructure -> Purple / Violet
  if (norm.contains('estate') ||
      norm.contains('propert') ||
      norm.contains('infra') ||
      norm.contains('realt')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF4C1D95).withAlpha(140)
          : const Color(0xFFF5F3FF),
      fg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
      border: isDark
          ? const Color(0xFF7C3AED).withAlpha(100)
          : const Color(0xFFDDD6FE),
    );
  }

  // 4. IT & Cloud Software -> Indigo / Royal Blue
  if (norm.contains('it') ||
      norm.contains('software') ||
      norm.contains('cloud') ||
      norm.contains('tech')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF312E81).withAlpha(140)
          : const Color(0xFFEEF2FF),
      fg: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
      border: isDark
          ? AppColors.primary.withAlpha(100)
          : const Color(0xFFC7D2FE),
    );
  }

  // 5. Manufacturing & Hardware -> Slate / Zinc
  if (norm.contains('manufactur') ||
      norm.contains('hardw') ||
      norm.contains('industr') ||
      norm.contains('steel')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF1E293B).withAlpha(160)
          : const Color(0xFFF1F5F9),
      fg: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      border: isDark
          ? const Color(0xFF475569).withAlpha(120)
          : const Color(0xFFCBD5E1),
    );
  }

  // 6. Digital Marketing & SEO -> Cyan / Sky Blue
  if (norm.contains('market') ||
      norm.contains('seo') ||
      norm.contains('digital') ||
      norm.contains('media') ||
      norm.contains('advert')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF164E63).withAlpha(140)
          : const Color(0xFFECFEFF),
      fg: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490),
      border: isDark
          ? const Color(0xFF0891B2).withAlpha(100)
          : const Color(0xFFA5F3FC),
    );
  }

  // 7. Finance, Audit & Tax -> Rose / Crimson
  if (norm.contains('financ') ||
      norm.contains('tax') ||
      norm.contains('audit') ||
      norm.contains('wealth') ||
      norm.contains('account') ||
      norm.contains('bank')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF881337).withAlpha(140)
          : const Color(0xFFFFF1F2),
      fg: isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C),
      border: isDark
          ? const Color(0xFFE11D48).withAlpha(100)
          : const Color(0xFFFECDD3),
    );
  }

  // 8. Logistics & Supply Chain -> Orange / Bronze
  if (norm.contains('logist') ||
      norm.contains('supply') ||
      norm.contains('transport') ||
      norm.contains('cargo')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF7C2D12).withAlpha(140)
          : const Color(0xFFFFEDD5),
      fg: isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C),
      border: isDark
          ? const Color(0xFFEA580C).withAlpha(100)
          : const Color(0xFFFED7AA),
    );
  }

  // 9. Architecture & Interiors -> Lime / Olive
  if (norm.contains('architect') ||
      norm.contains('interior') ||
      norm.contains('design') ||
      norm.contains('decor')) {
    return _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF365314).withAlpha(140)
          : const Color(0xFFF7FEE7),
      fg: isDark ? const Color(0xFFA3E635) : const Color(0xFF4D7C0F),
      border: isDark
          ? const Color(0xFF65A30D).withAlpha(100)
          : const Color(0xFFD9F99D),
    );
  }

  // Deterministic fallback for any other category
  final hash = norm.hashCode.abs();
  final palettes = [
    _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF312E81).withAlpha(140)
          : const Color(0xFFEEF2FF),
      fg: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
      border: isDark
          ? AppColors.primary.withAlpha(100)
          : const Color(0xFFC7D2FE),
    ),
    _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF064E3B).withAlpha(140)
          : const Color(0xFFECFDF5),
      fg: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
      border: isDark
          ? const Color(0xFF059669).withAlpha(100)
          : const Color(0xFFA7F3D0),
    ),
    _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF4C1D95).withAlpha(140)
          : const Color(0xFFF5F3FF),
      fg: isDark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
      border: isDark
          ? const Color(0xFF7C3AED).withAlpha(100)
          : const Color(0xFFDDD6FE),
    ),
    _CategoryBadgeStyle(
      bg: isDark
          ? const Color(0xFF164E63).withAlpha(140)
          : const Color(0xFFECFEFF),
      fg: isDark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490),
      border: isDark
          ? const Color(0xFF0891B2).withAlpha(100)
          : const Color(0xFFA5F3FC),
    ),
  ];
  return palettes[hash % palettes.length];
}

/// Screen displaying all Visitor check-in submissions in structured rows and columns.
class VisitorManagementScreen extends ConsumerStatefulWidget {
  const VisitorManagementScreen({super.key});

  @override
  ConsumerState<VisitorManagementScreen> createState() =>
      _VisitorManagementScreenState();
}

class _VisitorManagementScreenState
    extends ConsumerState<VisitorManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _showVisitorDetailsDialog(
    BuildContext context,
    CheckInSubmission visitor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = context.screenWidth >= 600;

    Widget buildDetailContent(BuildContext modalCtx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWide)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: AppRadius.fullAll,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Visitor Verification Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.of(modalCtx).pop(),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 12),

          if (visitor.isFlagged) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(isDark ? 35 : 20),
                borderRadius: AppRadius.mdAll,
                border: Border.all(
                  color: const Color(0xFFEF4444).withAlpha(60),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.flag_rounded, color: Color(0xFFEF4444), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Flagged as Suspicious / Invalid Check-in',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _buildDetailTextRow(context, 'Full Name', visitor.userName),
          _buildDetailTextRow(context, 'Phone Number', visitor.userPhone),
          if (visitor.userEmail != null && visitor.userEmail!.isNotEmpty)
            _buildDetailTextRow(context, 'Email Address', visitor.userEmail!),
          _buildDetailTextRow(
            context,
            'Company Name',
            visitor.companyName?.isNotEmpty == true
                ? visitor.companyName!
                : '—',
          ),
          if (visitor.category?.isNotEmpty == true)
            _buildDetailRow(
              context,
              'Business Category',
              _buildCategoryBadge(visitor.category!, isDark),
            ),
          _buildDetailTextRow(
            context,
            'Invited By Member',
            visitor.invitedByMember?.isNotEmpty == true
                ? visitor.invitedByMember!
                : '—',
            color: AppColors.primary,
          ),
          _buildDetailTextRow(
            context,
            'Check-in Timestamp',
            DateFormat('dd MMM yyyy, hh:mm a').format(visitor.timestamp),
            color: visitor.isEdited ? const Color(0xFFD97706) : null,
          ),
          _buildDetailRow(
            context,
            'GPS Status',
            _buildGpsStatusBadge(visitor.distanceMeters, isDark),
          ),
          if (visitor.locationName.isNotEmpty)
            _buildDetailTextRow(context, 'Venue', visitor.locationName),
          if (visitor.distanceMeters > 0)
            _buildDetailTextRow(
              context,
              'GPS Distance',
              '${visitor.distanceMeters.toStringAsFixed(1)}m from venue',
            ),
          if (visitor.userLatitude != 0 && visitor.userLongitude != 0)
            _buildDetailTextRow(
              context,
              'GPS Coordinates',
              '${visitor.userLatitude.toStringAsFixed(4)}, ${visitor.userLongitude.toStringAsFixed(4)}',
            ),
          _buildDetailTextRow(context, 'Submission ID', visitor.id),
          if (visitor.isEdited)
            _buildDetailRow(
              context,
              'Admin Status',
              const AppBadge(
                label: 'Edited by Admin',
                variant: AppBadgeVariant.warning,
              ),
            ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(modalCtx).pop();
                    _showEditVisitorDialog(context, visitor);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit Details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(modalCtx).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF475569),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (isWide) {
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (dialogCtx) => Dialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: buildDetailContent(dialogCtx),
              ),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => SafeArea(
          child: Container(
            margin: const EdgeInsets.only(top: 40),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SingleChildScrollView(child: buildDetailContent(sheetCtx)),
          ),
        ),
      );
    }
  }

  void _showEditVisitorDialog(BuildContext context, CheckInSubmission visitor) {
    final nameController = TextEditingController(text: visitor.userName);
    final phoneController = TextEditingController(text: visitor.userPhone);
    final emailController = TextEditingController(
      text: visitor.userEmail ?? '',
    );
    final companyController = TextEditingController(
      text: visitor.companyName ?? '',
    );
    final categoryController = TextEditingController(
      text: visitor.category ?? '',
    );
    final invitedByController = TextEditingController(
      text: visitor.invitedByMember ?? '',
    );
    final venueController = TextEditingController(text: visitor.locationName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final screenWidth = MediaQuery.of(ctx).size.width;
          final isMobile = screenWidth < 600;

          final fieldBgColor = isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF8FAFC);
          final defaultBorderColor = isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0);
          final labelColor = isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF475569);
          final iconColor = isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B);

          InputDecoration buildDecoration({
            required String hint,
            required Widget prefixIcon,
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: fieldBgColor,
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: defaultBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: defaultBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.92 : 520,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                const Text(
                                  'Edit Visitor Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Update visitor profile, company, and invitation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: labelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full Name
                      Text(
                        'Full Name *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 14),
                        decoration: buildDecoration(
                          hint: 'Enter visitor name',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: iconColor,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Please enter visitor name'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      Text(
                        'Phone Number *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 14),
                        decoration: buildDecoration(
                          hint: 'Enter phone number',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            size: 18,
                            color: iconColor,
                          ),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Please enter phone number'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Email Address
                      Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 14),
                        decoration: buildDecoration(
                          hint: 'Enter email address (optional)',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            size: 18,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Company & Category
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Company / Business',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: companyController,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: buildDecoration(
                                    hint: 'e.g. FireAI',
                                    prefixIcon: Icon(
                                      Icons.business_outlined,
                                      size: 18,
                                      color: iconColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Business Category',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: labelColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: categoryController,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: buildDecoration(
                                    hint: 'e.g. IT Services',
                                    prefixIcon: Icon(
                                      Icons.category_outlined,
                                      size: 18,
                                      color: iconColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Invited By Member with Registered Members Dropdown
                      Text(
                        'Invited By Member',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Consumer(
                        builder: (consumerCtx, consumerRef, _) {
                          final employeesAsync = consumerRef.watch(
                            employeesStreamProvider,
                          );
                          final members = employeesAsync.value ?? [];

                          return TextFormField(
                            controller: invitedByController,
                            style: const TextStyle(fontSize: 14),
                            decoration: buildDecoration(
                              hint: 'Member who invited visitor',
                              prefixIcon: Icon(
                                Icons.person_add_alt_1_outlined,
                                size: 18,
                                color: iconColor,
                              ),
                              suffixIcon: members.isNotEmpty
                                  ? PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.arrow_drop_down_rounded,
                                        color: iconColor,
                                      ),
                                      tooltip: 'Select registered member',
                                      onSelected: (String memberName) {
                                        setDialogState(() {
                                          invitedByController.text = memberName;
                                        });
                                      },
                                      itemBuilder: (popupCtx) => members
                                          .map(
                                            (m) => PopupMenuItem<String>(
                                              value: m.name,
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.person_rounded,
                                                    size: 16,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(m.name),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Venue / Location
                      Text(
                        'Venue / Location',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: venueController,
                        style: const TextStyle(fontSize: 14),
                        decoration: buildDecoration(
                          hint: 'Enter venue / chapter location',
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: labelColor,
                                side: BorderSide(color: defaultBorderColor),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final now = DateTime.now();
                                final updated = visitor.copyWith(
                                  userName: nameController.text.trim(),
                                  userPhone: phoneController.text.trim(),
                                  userEmail:
                                      emailController.text.trim().isNotEmpty
                                      ? emailController.text.trim()
                                      : null,
                                  companyName:
                                      companyController.text.trim().isNotEmpty
                                      ? companyController.text.trim()
                                      : '',
                                  category:
                                      categoryController.text.trim().isNotEmpty
                                      ? categoryController.text.trim()
                                      : '',
                                  invitedByMember:
                                      invitedByController.text.trim().isNotEmpty
                                      ? invitedByController.text.trim()
                                      : null,
                                  locationName: venueController.text.trim(),
                                  isEdited: true,
                                  editedAt: now,
                                  timestamp: visitor.timestamp,
                                );

                                Navigator.pop(dialogCtx);

                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  final repo = ref.read(
                                    checkInRepositoryProvider,
                                  );
                                  await repo.updateCheckIn(updated);

                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Updated visitor "${updated.userName}"',
                                        ),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: AppRadius.mdAll,
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update visitor: $e',
                                        ),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Save Changes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
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

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    Widget valueWidget,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: valueWidget),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTextRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return _buildDetailRow(
      context,
      label,
      SelectableText(
        value,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(String category, bool isDark) {
    final style = _getCategoryBadgeStyle(category, isDark);
    return Tooltip(
      message: 'Business Category: $category',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: style.border, width: 1),
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: style.fg,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGpsStatusBadge(double distanceMeters, bool isDark) {
    Color bg;
    Color fg;
    String statusText;
    IconData icon;
    String tooltip;

    if (distanceMeters < 0.0 || distanceMeters.isNaN) {
      bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      fg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      statusText = 'Unverified';
      icon = Icons.help_outline_rounded;
      tooltip = 'GPS verification pending or unavailable';
    } else if (distanceMeters <= 500.0) {
      bg = const Color(0xFF10B981).withAlpha(isDark ? 40 : 25);
      fg = const Color(0xFF059669);
      statusText = 'On-site';
      icon = Icons.check_circle_outline_rounded;
      tooltip = distanceMeters == 0.0
          ? 'GPS Verified: On-site at venue (Within 500m geofence)'
          : 'GPS Verified: ${distanceMeters.toStringAsFixed(1)}m from venue center (Within 500m geofence)';
    } else if (distanceMeters <= 1500.0) {
      bg = const Color(0xFFF59E0B).withAlpha(isDark ? 40 : 25);
      fg = const Color(0xFFD97706);
      statusText = 'Off-site';
      icon = Icons.warning_amber_rounded;
      tooltip =
          'GPS Warning: ${distanceMeters.toStringAsFixed(1)}m from venue center (Outside 500m geofence)';
    } else {
      bg = const Color(0xFFEF4444).withAlpha(isDark ? 40 : 25);
      fg = const Color(0xFFDC2626);
      statusText = 'Failed';
      icon = Icons.cancel_outlined;
      tooltip =
          'GPS Anomaly: ${distanceMeters.toStringAsFixed(1)}m from venue center (Significantly distant)';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = context.isMobile;

    final filteredVisitorsAsync = ref.watch(filteredVisitorsProvider);
    final filterState = ref.watch(visitorFilterProvider);

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
            // 1. Fixed Header Section (Desktop/Tablet only; on mobile Shell AppBar shows screen title)
            if (!isMobile) ...[
              const AppPageHeader(
                title: 'Visitors Overview',
                subtitle: 'All guest check-in records with company, category, and member invitation details',
              ),
              const SizedBox(height: 12),
            ],

            // 2. Fixed Filters Toolbar
            _buildToolbar(context, theme, isDark, filterState),
            const SizedBox(height: 12),

            // 3. ONLY Data Table is Scrollable with Pagination!
            Expanded(
              child: filteredVisitorsAsync.when(
                data: (visitors) {
                  if (visitors.isEmpty) {
                    return AppCard(
                      child: AppEmptyView(
                        icon: Icons.search_off_rounded,
                        message:
                            filterState.searchQuery.isNotEmpty ||
                                filterState.selectedDate != null ||
                                filterState.selectedCategory != null
                            ? 'No visitor records match the selected filters.'
                            : 'No visitors have checked in yet.',
                        actionLabel: 'Reset Filters',
                        action: () {
                          _searchController.clear();
                          ref
                              .read(visitorFilterProvider.notifier)
                              .resetFilters();
                        },
                      ),
                    );
                  }

                  if (isMobile) {
                    return _buildMobileVisitorList(
                      context,
                      theme,
                      isDark,
                      visitors,
                    );
                  }

                  return _buildVisitorsTable(context, theme, isDark, visitors);
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
                      child: Text('Error loading visitors: $err'),
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

  Widget _buildThursdayDateDropdown(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    VisitorFilterState filterState,
  ) {
    final isMobile = context.isMobile;
    final allThursdays = ref.watch(allThursdayDatesProvider);
    final selectedDate = filterState.selectedDate;
    final isSelected = selectedDate != null;

    final displayText = isSelected
        ? DateFormat('EEEE, dd MMM yyyy').format(selectedDate)
        : 'All Thursdays / All Dates';

    return Builder(
      builder: (btnContext) {
        return InkWell(
          onTap: () {
            showSearchableThursdayDateDropdown(
              context: btnContext,
              isDark: isDark,
              selectedDate: selectedDate,
              allThursdays: allThursdays,
              onDateSelected: (date) {
                ref.read(visitorFilterProvider.notifier).setSelectedDate(date);
              },
            );
          },
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(isDark ? 40 : 20)
                  : (isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155)),
                  ),
                ),
                if (isMobile) const Spacer(),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => ref
                        .read(visitorFilterProvider.notifier)
                        .setSelectedDate(null),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    VisitorFilterState filterState,
  ) {
    final isMobile = context.isMobile;

    final searchInput = SizedBox(
      width: isMobile ? double.infinity : 250,
      height: 40,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search visitor, company, member...',
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
                    ref.read(visitorFilterProvider.notifier).setSearchQuery('');
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
          ref.read(visitorFilterProvider.notifier).setSearchQuery(val);
        },
      ),
    );

    final dateDropdown = _buildThursdayDateDropdown(
      context,
      theme,
      isDark,
      filterState,
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
              children: [searchInput, const SizedBox(height: 8), dateDropdown],
            )
          : Wrap(
              spacing: 14,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [searchInput, dateDropdown],
            ),
    );
  }

  Widget _buildVisitorsTable(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<CheckInSubmission> visitors,
  ) {
    const double colIndexWidth = 44.0;
    const double colActionsWidth = 96.0;
    const double rowHeight = 62.0;
    const double headerHeight = 50.0;

    // Shared flex ratios to guarantee perfect header & row alignment and equal spacing:
    const int flexVisitor = 4;
    const int flexPhone = 3;
    const int flexCompany = 3;
    const int flexCategory = 3;
    const int flexInvitedBy = 3;
    const int flexCheckInTime = 3;
    const int flexGpsStatus = 3;

    final borderColor = isDark
        ? AppColors.outlineDark
        : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minTableWidth = constraints.maxWidth < 1050
            ? 1050.0
            : constraints.maxWidth;
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
              // Table Header (Fixed - No vertical scroll)
              Container(
                height: headerHeight,
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
                    _buildHeaderCol('#', colIndexWidth, isDark),
                    _buildHeaderColFlex('VISITOR', flexVisitor, isDark),
                    _buildHeaderColFlex('PHONE', flexPhone, isDark),
                    _buildHeaderColFlex('COMPANY', flexCompany, isDark),
                    _buildHeaderColFlex('CATEGORY', flexCategory, isDark),
                    _buildHeaderColFlex('INVITED BY', flexInvitedBy, isDark),
                    _buildHeaderColFlex(
                      'CHECK-IN TIME',
                      flexCheckInTime,
                      isDark,
                    ),
                    _buildHeaderColFlex('GPS STATUS', flexGpsStatus, isDark),
                    _buildHeaderCol(
                      'ACTIONS',
                      colActionsWidth,
                      isDark,
                      alignment: Alignment.center,
                    ),
                  ],
                ),
              ),

              // Only Vertical Scroll for Data Rows
              Expanded(
                child: Scrollbar(
                  controller: _verticalScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _verticalScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visitors.length,
                    itemBuilder: (context, index) {
                      final globalIndex = index + 1;
                      final v = visitors[index];
                      final isEven = index % 2 == 0;
                      final rowBg = isEven
                          ? Colors.transparent
                          : (isDark
                                ? const Color(0xFF1E293B).withAlpha(50)
                                : const Color(0xFFF8FAFC));

                      return Container(
                        height: rowHeight,
                        decoration: BoxDecoration(
                          color: v.isFlagged
                              ? const Color(0xFFEF4444)
                                    .withAlpha(isDark ? 25 : 12)
                              : rowBg,
                          border: Border(
                            bottom: BorderSide(
                              color: borderColor.withAlpha(60),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Index
                            Container(
                              width: colIndexWidth,
                              alignment: Alignment.center,
                              child: Text(
                                '$globalIndex',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),

                            // Visitor Name & Email
                            Expanded(
                              flex: flexVisitor,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color:
                                            (v.isFlagged
                                                    ? const Color(0xFFEF4444)
                                                    : AppColors.primary)
                                                .withAlpha(25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          v.userName.isNotEmpty
                                              ? v.userName[0].toUpperCase()
                                              : 'V',
                                          style: TextStyle(
                                            color: v.isFlagged
                                                ? const Color(0xFFEF4444)
                                                : AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  v.userName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF0F172A,
                                                          ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (v.isFlagged) ...[
                                                const SizedBox(width: 4),
                                                const Tooltip(
                                                  message: 'Flagged as suspicious / invalid check-in',
                                                  child: Icon(
                                                    Icons.flag_rounded,
                                                    size: 14,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (v.userEmail != null &&
                                              v.userEmail!.isNotEmpty)
                                            Text(
                                              v.userEmail!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? const Color(0xFF64748B)
                                                    : const Color(0xFF94A3B8),
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

                            // Phone
                            Expanded(
                              flex: flexPhone,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  v.userPhone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Company
                            Expanded(
                              flex: flexCompany,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: v.companyName?.isNotEmpty == true
                                    ? Row(
                                        children: [
                                          Icon(
                                            Icons.business_rounded,
                                            size: 14,
                                            color: isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              v.companyName!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        '—',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                              ),
                            ),

                            // Category
                            Expanded(
                              flex: flexCategory,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: v.category?.isNotEmpty == true
                                    ? _buildCategoryBadge(v.category!, isDark)
                                    : const Text(
                                        '—',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                              ),
                            ),

                            // Invited By (Interactive Filter Link with Hover Affordance)
                            Expanded(
                              flex: flexInvitedBy,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: v.invitedByMember?.isNotEmpty == true
                                    ? Tooltip(
                                        message:
                                            'Filter visitors invited by ${v.invitedByMember!}',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            mouseCursor:
                                                SystemMouseCursors.click,
                                            onTap: () {
                                              _searchController.text =
                                                  v.invitedByMember!;
                                              ref
                                                  .read(
                                                    visitorFilterProvider
                                                        .notifier,
                                                  )
                                                  .setSearchQuery(
                                                    v.invitedByMember!,
                                                  );
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.person_rounded,
                                                    size: 14,
                                                    color: AppColors.primary,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Flexible(
                                                    child: Text(
                                                      v.invitedByMember!,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppColors.primary,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        decorationStyle:
                                                            TextDecorationStyle
                                                                .dotted,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        '—',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                              ),
                            ),

                            // Check-In Time
                            Expanded(
                              flex: flexCheckInTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('dd MMM yyyy')
                                          .format(v.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      DateFormat('hh:mm a').format(v.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // GPS Status
                            Expanded(
                              flex: flexGpsStatus,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: _buildGpsStatusBadge(
                                  v.distanceMeters,
                                  isDark,
                                ),
                              ),
                            ),

                            // Actions (Edit Details & View Details)
                            Container(
                              width: colActionsWidth,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                    label:
                                        'Edit visitor details for ${v.userName}',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 17,
                                        color: AppColors.primary,
                                      ),
                                      tooltip: 'Edit Visitor Details',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      style: IconButton.styleFrom(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      splashRadius: 16,
                                      onPressed: () =>
                                          _showEditVisitorDialog(context, v),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Semantics(
                                    label:
                                        'View visitor details for ${v.userName}',
                                    button: true,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                        color: isDark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                      tooltip: 'View Visitor Details',
                                      padding: const EdgeInsets.all(4),
                                      constraints: const BoxConstraints(
                                        minWidth: 28,
                                        minHeight: 28,
                                      ),
                                      style: IconButton.styleFrom(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      splashRadius: 16,
                                      onPressed: () =>
                                          _showVisitorDetailsDialog(context, v),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );

        if (constraints.maxWidth < 950) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tableContent,
          );
        }
        return tableContent;
      },
    );
  }

  Widget _buildMobileVisitorList(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<CheckInSubmission> visitors,
  ) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: visitors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final v = visitors[index];

        return AppCard(
          padding: const EdgeInsets.all(14),
          borderRadius: AppRadius.mdAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color:
                          (v.isFlagged
                                  ? const Color(0xFFEF4444)
                                  : AppColors.primary)
                              .withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        v.userName.isNotEmpty
                            ? v.userName[0].toUpperCase()
                            : 'V',
                        style: TextStyle(
                          color: v.isFlagged
                              ? const Color(0xFFEF4444)
                              : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                v.userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (v.isFlagged) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.flag_rounded,
                                size: 14,
                                color: Color(0xFFEF4444),
                              ),
                            ],
                          ],
                        ),
                        if (v.userPhone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            v.userPhone,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Edit Visitor Details',
                        onPressed: () => _showEditVisitorDialog(context, v),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        tooltip: 'View Visitor Details',
                        onPressed: () => _showVisitorDetailsDialog(context, v),
                      ),
                    ],
                  ),
                ],
              ),
              if (v.companyName?.isNotEmpty == true ||
                  v.category?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (v.companyName?.isNotEmpty == true)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            v.companyName!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    if (v.category?.isNotEmpty == true)
                      _buildCategoryBadge(v.category!, isDark),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: theme.dividerColor.withAlpha(isDark ? 30 : 20),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (v.invitedByMember?.isNotEmpty == true)
                    Flexible(
                      child: InkWell(
                        onTap: () {
                          _searchController.text = v.invitedByMember!;
                          ref
                              .read(visitorFilterProvider.notifier)
                              .setSearchQuery(v.invitedByMember!);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Invited by ${v.invitedByMember!}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  _buildGpsStatusBadge(v.distanceMeters, isDark),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(v.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCol(
    String title,
    double width,
    bool isDark, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: alignment,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildHeaderColFlex(String title, int flex, bool isDark) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
