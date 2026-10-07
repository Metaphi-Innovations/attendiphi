import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/member_photo.dart';
import '../../../app_config/presentation/widgets/check_in_restrictions_toggle.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../providers/admin_dashboard_provider.dart';

Widget _buildAttendanceRecordAvatar({
  required CheckInSubmission record,
  required List<Employee>? employees,
  required double size,
}) {
  final liveMember = employees == null || employees.isEmpty
      ? null
      : EmployeeLookup.forCheckIn(employees, record) ??
          EmployeeLookup.byPhone(employees, record.userPhone) ??
          EmployeeLookup.byName(employees, record.userName);

  Widget fallback() => _buildFallbackRecordInitials(
        liveMember?.name ?? record.userName,
        size,
      );

  // Member identity displays use the live profile photo so admin edits
  // appear immediately. Selfies remain for substitutes/visitors.
  if (liveMember != null &&
      (record.type.isMember ||
          record.type.isAbsent ||
          record.type.isNotCheckedIn ||
          record.type.isSubstitute)) {
    final photo = liveMember.photoUrl?.trim() ?? '';
    if (photo.isNotEmpty) {
      return ClipRRect(
        borderRadius: AppRadius.xsAll,
        child: MemberPhoto(
          member: liveMember,
          width: size,
          height: size,
          errorBuilder: (ctx, err, stack) => fallback(),
        ),
      );
    }
  }

  final photoBytes = ImageUtils.base64ToBytes(record.photoBase64);
  if (photoBytes != null) {
    return ClipRRect(
      borderRadius: AppRadius.xsAll,
      child: Image.memory(
        photoBytes,
        width: size,
        height: size,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => fallback(),
      ),
    );
  }

  return fallback();
}

Widget _buildFallbackRecordInitials(String userName, double size) {
  final initial = userName.trim().isNotEmpty ? userName.trim()[0].toUpperCase() : 'M';
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.primary.withAlpha(25),
      borderRadius: AppRadius.xsAll,
      border: Border.all(
        color: AppColors.primary.withAlpha(40),
      ),
    ),
    child: Center(
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

/// Highly responsive real-time Admin Dashboard for mobile, tablet, and desktop screens.

String _formatDate(DateTime? dt) {
  if (dt == null) return '—';
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  return '$day $month $year';
}

String _formatTime(DateTime? dt) {
  if (dt == null) return '';
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

/// Formats GPS distance for list tiles.
/// Shows 'On-site' with clean status representation (no redundant checkmark icon inside string).
String _formatGpsDistance(CheckInSubmission record) {
  final latPrefix = record.userLatitude.toStringAsFixed(2);
  final lonPrefix = record.userLongitude.toStringAsFixed(2);
  final isSameCoord =
      (latPrefix == '18.99' && lonPrefix == '72.82') ||
      (latPrefix == '19.08' && lonPrefix == '72.91');

  if (record.distanceMeters == 0 ||
      (isSameCoord && record.distanceMeters <= 150)) {
    return 'On-site';
  }
  if (record.distanceMeters >= 1000) {
    return '${(record.distanceMeters / 1000).toStringAsFixed(1)}km away';
  }
  return '${record.distanceMeters.round()}m away';
}

/// Formats phone number for clean reference viewing (e.g. 83560 11246).
String _formatPhoneNumber(String phone) {
  final clean = phone.replaceAll(RegExp(r'\s+'), '');
  if (clean.startsWith('+91') && clean.length == 13) {
    return '${clean.substring(3, 8)} ${clean.substring(8)}';
  }
  if (clean.length == 10) {
    return '${clean.substring(0, 5)} ${clean.substring(5)}';
  }
  return phone;
}

/// Formats GPS distance for detail modal.
String _formatGpsDistanceDetail(CheckInSubmission record) {
  final latPrefix = record.userLatitude.toStringAsFixed(2);
  final lonPrefix = record.userLongitude.toStringAsFixed(2);
  final isSameCoord =
      (latPrefix == '18.99' && lonPrefix == '72.82') ||
      (latPrefix == '19.08' && lonPrefix == '72.91');

  if (record.distanceMeters == 0 ||
      (isSameCoord && record.distanceMeters <= 150)) {
    return '✓ On-site (Same Location)';
  }
  if (record.distanceMeters >= 1000) {
    return '${(record.distanceMeters / 1000).toStringAsFixed(1)}km (±${record.gpsAccuracy.round()}m)';
  }
  return '${record.distanceMeters.round()}m (±${record.gpsAccuracy.round()}m)';
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      // Trigger when within 200px of bottom
      if (currentScroll >= (maxScroll - 200)) {
        ref.read(paginatedCheckInsProvider.notifier).loadNextPage();
      }
    }
  }

  Future<void> _toggleVerifyCheckIn(CheckInSubmission record) async {
    final newVerified = !record.isVerified;
    final isAbsent = record.type.isAbsent;
    final isNotCheckedIn = record.type.isNotCheckedIn;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            newVerified
                ? (isAbsent ? 'Verify Absence' : 'Verify Attendance')
                : 'Unverify Record',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            newVerified
                ? (isAbsent
                    ? 'Do you want to verify that ${record.userName} was Absent?'
                    : (isNotCheckedIn
                        ? 'Do you want to verify attendance for ${record.userName}?'
                        : 'Do you want to verify this check-in for ${record.userName}?'))
                : 'Do you want to unverify this record for ${record.userName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    newVerified ? AppColors.success : AppColors.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(newVerified ? 'Verify' : 'Unverify'),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    final updatedRecord = record.copyWith(
      type: isNotCheckedIn ? CheckInType.member : record.type,
      isVerified: newVerified,
      verifiedAt: newVerified ? DateTime.now() : null,
      verifiedBy: newVerified ? 'Admin' : null,
    );

    try {
      final repository = ref.read(checkInRepositoryProvider);
      await repository.updateCheckIn(updatedRecord);
      ref
          .read(paginatedCheckInsProvider.notifier)
          .updateCheckInItem(updatedRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newVerified
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  newVerified
                      ? (isAbsent
                          ? 'Verified "${record.userName}" as Absent'
                          : 'Verified "${record.userName}" as Present')
                      : 'Unmarked verification for "${record.userName}"',
                ),
              ],
            ),
            backgroundColor:
                newVerified ? AppColors.success : const Color(0xFF475569),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update verification: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditCheckInDialog(BuildContext context, CheckInSubmission record) {
    final nameController = TextEditingController(text: record.userName);
    final phoneController = TextEditingController(text: record.userPhone);
    final venueController = TextEditingController(text: record.locationName);
    var selectedType = record.type == CheckInType.notCheckedIn
        ? CheckInType.member
        : record.type;
    final isVerified = record.isVerified;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final screenWidth = MediaQuery.of(ctx).size.width;
          final isMobile = screenWidth < 600;

          final fieldBgColor =
              isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
          final defaultBorderColor =
              isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
          final labelColor =
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
          final iconColor =
              isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

          InputDecoration buildDecoration({
            required String hint,
            required Widget prefixIcon,
          }) {
            return InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: fieldBgColor,
              prefixIcon: prefixIcon,
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

          Widget buildTypeOption({
            required CheckInType type,
            required String label,
            required Color accentColor,
            required IconData icon,
          }) {
            final isSelected = selectedType == type;
            return InkWell(
              onTap: () => setDialogState(() => selectedType = type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withAlpha(25) : fieldBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? accentColor : defaultBorderColor,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : icon,
                      size: 16,
                      color: isSelected ? accentColor : iconColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isSelected ? accentColor : labelColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                maxWidth: isMobile ? screenWidth * 0.92 : 480,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
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
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Edit Check-In Details',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: iconColor,
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Full Name
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        decoration: buildDecoration(
                          hint: 'Enter attendee name',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Phone Number
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: buildDecoration(
                          hint: 'Enter phone number',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Attendance Type
                      Text(
                        'Attendance Type',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 6),


                      // Type options: Member, Substitute, Absent
                      Row(
                        children: [
                          Expanded(
                            child: buildTypeOption(
                              type: CheckInType.member,
                              label: 'Member',
                              accentColor: AppColors.success,
                              icon: Icons.verified_user_outlined,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: buildTypeOption(
                              type: CheckInType.substitute,
                              label: 'Substitute',
                              accentColor: AppColors.warning,
                              icon: Icons.swap_horiz_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: buildTypeOption(
                              type: CheckInType.absent,
                              label: 'Absent',
                              accentColor: AppColors.error,
                              icon: Icons.person_off_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),


                      const SizedBox(height: 22),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
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
                                final isMarkedAbsent = selectedType == CheckInType.absent;
                                final now = DateTime.now();
                                final updated = record.copyWith(
                                  userName: nameController.text.trim(),
                                  userPhone: phoneController.text.trim(),
                                  locationName: venueController.text.trim(),
                                  type: selectedType,
                                  isVerified: isMarkedAbsent ? false : isVerified,
                                  isEdited: true,
                                  editedAt: now,
                                  timestamp: record.timestamp,
                                  verifiedAt: (isVerified && !isMarkedAbsent)
                                      ? (record.verifiedAt ?? now)
                                      : null,
                                  verifiedBy: (isVerified && !isMarkedAbsent)
                                      ? (record.verifiedBy ?? 'Admin')
                                      : null,
                                );

                                Navigator.pop(dialogCtx);

                                try {
                                  final repo =
                                      ref.read(checkInRepositoryProvider);
                                  await repo.updateCheckIn(updated);
                                  ref
                                      .read(paginatedCheckInsProvider.notifier)
                                      .updateCheckInItem(updated);

                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Updated check-in for "${updated.userName}"',
                                        ),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update: $e'),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Save Changes'),
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

  void _showDetailModal(BuildContext context, CheckInSubmission record) {
    final photoBytes = ImageUtils.base64ToBytes(record.photoBase64);
    final theme = Theme.of(context);
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
                  'Attendance Verification',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => Navigator.of(modalCtx).pop(),
              ),
            ],
          ),
          const Divider(height: 16),

          Builder(
            builder: (context) {
              if (photoBytes != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: Image.memory(
                            photoBytes,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          record.type.isSubstitute
                              ? 'Substitute Face Photo'
                              : 'Attendee Face Photo',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final emps = ref.watch(employeesStreamProvider).value;
              final member = emps == null
                  ? null
                  : EmployeeLookup.forCheckIn(emps, record) ??
                      EmployeeLookup.byPhone(emps, record.userPhone) ??
                      EmployeeLookup.byName(emps, record.userName);
              final photoUrl = member?.photoUrl?.trim();
              if (member != null && photoUrl != null && photoUrl.isNotEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: MemberPhoto(
                            member: member,
                            width: 110,
                            height: 110,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enrolled Profile Photo',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          _DetailItem(label: 'Member Name', value: record.userName),
          if (record.type.isSubstitute &&
              (record.substituteName?.isNotEmpty ?? false))
            _DetailItem(
              label: 'Substitute Name',
              value: record.substituteName!,
            ),
          _DetailItem(label: 'Phone Number', value: record.userPhone),
          _DetailItem(label: 'Attendance Type', value: record.type.displayName),
          _DetailItem(label: 'Venue', value: record.locationName),
          _DetailItem(
            label: 'GPS Distance',
            value: (record.type == CheckInType.absent ||
                    record.type.isNotCheckedIn)
                ? '-'
                : _formatGpsDistanceDetail(record),
          ),
          _DetailItem(
            label: 'GPS Coordinates',
            value: (record.type == CheckInType.absent ||
                    record.type.isNotCheckedIn)
                ? '-'
                : '${record.userLatitude.toStringAsFixed(4)}, ${record.userLongitude.toStringAsFixed(4)}',
          ),
          _DetailItem(
            label: 'Timestamp',
            value: record.type.isNotCheckedIn
                ? '-'
                : (record.isEdited
                    ? '${record.timestamp.formattedDateTime} (Edited by Admin)'
                    : record.timestamp.formattedDateTime),
          ),
          _DetailItem(label: 'Submission ID', value: record.id),
          _DetailItem(
            label: 'Admin Status',
            value: record.type.isNotCheckedIn
                ? 'Not Checked In'
                : (record.isVerified
                    ? (record.type.isAbsent
                        ? '✓ Absence Verified by Admin'
                        : '✓ Verified by Admin')
                    : (record.type.isAbsent
                        ? 'Pending Absence Verification'
                        : 'Pending Verification')),
          ),
          const SizedBox(height: 12),

          // Action buttons in modal
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(modalCtx).pop();
                    _toggleVerifyCheckIn(record);
                  },
                  icon: Icon(
                    record.isVerified
                        ? Icons.remove_done_rounded
                        : Icons.verified_rounded,
                    size: 16,
                  ),
                  label: Text(
                    record.isVerified
                        ? 'Unverify'
                        : (record.type.isAbsent ? 'Verify Absent' : 'Verify Present'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: record.isVerified
                        ? const Color(0xFF475569)
                        : AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(modalCtx).pop();
                    _showEditCheckInDialog(context, record);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Details'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (isWide) {
      final screenHeight = MediaQuery.sizeOf(context).height;
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (dialogCtx) => Dialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: screenHeight * 0.92,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
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
            child: SingleChildScrollView(
              child: buildDetailContent(sheetCtx),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = ref.watch(filteredPaginatedCheckInsProvider);
    final allCheckInsAsync = ref.watch(checkInsStreamProvider);
    final employeesAsync = ref.watch(employeesStreamProvider);
    final filterState = ref.watch(adminDashboardFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();

    // Compute metrics from stream providers (Dashboard excludes visitor records)
    final totalMembersCount =
        employeesAsync.value?.where((e) => e.isActive).length ?? 0;
    
    // Fetch the base records (all active members with attendance mapped)
    final baseRecordsAsync = ref.watch(baseDashboardRecordsProvider);
    final baseRecords = baseRecordsAsync.value ?? [];

    final dashboardRecords =
        baseRecords.where((r) => !r.type.isVisitor).toList();
    final totalCount = dashboardRecords.length;
    final memberCount =
        dashboardRecords.where((r) => r.type.isMember).length;
    final substituteCount =
        dashboardRecords.where((r) => r.type.isSubstitute).length;
    final absentCount =
        dashboardRecords.where((r) => r.type.isAbsent).length;
    final totalCheckIns = memberCount + substituteCount;

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 20.0,
      desktop: 28.0,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = screenWidth >= 768
        ? (screenWidth < 1024 ? 220.0 : 250.0)
        : 0.0;
    final availableWidth = screenWidth - sidebarWidth;
    final isWide = availableWidth >= 700;

    // Mobile / Small-Screen Scoped Layout (<700px): Fully Scrollable Root View
    if (!isWide) {
      return SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPadding, 12, hPadding, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mobile shell already shows the page title; keep toggle top-right.
              const Align(
                alignment: Alignment.centerRight,
                child: CheckInRestrictionsToggle(),
              ),
              const SizedBox(height: 8),
              _buildThursdayNotice(now),

              // 1. Metric Cards
              _buildMetrics(
                context,
                totalMembersCount,
                totalCheckIns,
                memberCount,
                substituteCount,
                absentCount,
                availableWidth,
              ),
              const SizedBox(height: 14),

              // 2. Search & Filter Bar + Legend
              _buildSearchFilterToolbar(
                context,
                theme,
                isDark,
                availableWidth,
                totalCount,
                memberCount,
                substituteCount,
                absentCount,
                filterState,
              ),
              const SizedBox(height: 12),

              // 3. Unified Scrollable Table Body for Mobile
              _buildMobileBody(
                context,
                theme,
                isDark,
                allCheckInsAsync,
                filteredRecords,
                availableWidth,
              ),
            ],
          ),
        ),
      );
    }

    // Web / Desktop Layout (>=700px): Unchanged Fixed Column with Independent Body Scroll
    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header (restrictions toggle top-right)
          _buildHeader(context, theme, isWide, totalCount, now, filterState),
          const SizedBox(height: 14),

          // Thursday notice (if today is not Thursday)
          _buildThursdayNotice(now),

          // 2. Metric Cards
          _buildMetrics(
            context,
            totalMembersCount,
            totalCheckIns,
            memberCount,
            substituteCount,
            absentCount,
            availableWidth,
          ),
          const SizedBox(height: 16),

          // 3. Search & Filter Bar
          _buildSearchFilterToolbar(
            context,
            theme,
            isDark,
            availableWidth,
            totalCount,
            memberCount,
            substituteCount,
            absentCount,
            filterState,
          ),
          const SizedBox(height: 14),

          // 4. Scrollable Table Area
          Expanded(
            child: _buildBody(
              context,
              theme,
              isDark,
              allCheckInsAsync,
              filteredRecords,
              availableWidth,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AsyncValue<List<CheckInSubmission>> allCheckInsAsync,
    List<CheckInSubmission> filteredRecords,
    double availableWidth,
  ) {
    if (allCheckInsAsync.isLoading && filteredRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CheckInCardSkeletonList(count: 3),
      );
    }

    if (allCheckInsAsync.hasError && filteredRecords.isEmpty) {
      return AppCard(
        elevation: 1,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: AppColors.error,
            ),
            const SizedBox(height: 8),
            Text(
              allCheckInsAsync.error.toString(),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.invalidate(checkInsStreamProvider),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredRecords.isEmpty) {
      return const AppEmptyView(
        message: 'No Check-In Records Found.\nNew check-ins will appear here in real-time as members submit attendance.',
        icon: Icons.how_to_reg_outlined,
      );
    }

    // Modern mobile-responsive record list for small screens (<600px)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ATTENDEES (${filteredRecords.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Colors.grey,
                ),
              ),
              if (allCheckInsAsync.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        AppCard(
          elevation: 2,
          padding: EdgeInsets.zero,
          borderRadius: AppRadius.mdAll,
          shadows: AppShadows.sm,
          child: ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRecords.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? AppColors.outlineDark.withAlpha(50)
                    : AppColors.outlineLight.withAlpha(120),
              ),
              itemBuilder: (context, index) {
                final record = filteredRecords[index];
                return _MobileCheckInRow(
                  index: index,
                  record: record,
                  isDark: isDark,
                  theme: theme,
                  employees: ref.watch(employeesStreamProvider).value,
                  onRecordTap: () => _showDetailModal(context, record),
                  onEditTap: () => _showEditCheckInDialog(context, record),
                  onVerifyTap: () => _toggleVerifyCheckIn(record),
                );
              },
            ),
          ),
        ),
        // Removed load more button for live sync
      ],
    );
  }

  DateTime _getActiveThursday(DateTime n) {
    if (n.weekday == DateTime.thursday) {
      return DateTime(n.year, n.month, n.day);
    }
    int daysSinceThursday = (n.weekday - DateTime.thursday) % 7;
    if (daysSinceThursday <= 0) daysSinceThursday += 7;
    return DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: daysSinceThursday));
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    bool isWide,
    int totalCount,
    DateTime now,
    AdminDashboardFilterState filterState,
  ) {
    final activeThursday = _getActiveThursday(now);
    final isThursday = now.weekday == DateTime.thursday;
    final String dateSubtitle;
    if (isThursday) {
      dateSubtitle =
          'Live attendance for today, ${DateFormat('EEEE, d MMM yyyy').format(now)}.';
    } else {
      final activeDateStr = DateFormat('EEEE, d MMM yyyy').format(activeThursday);
      dateSubtitle = 'Attendance records for $activeDateStr.';
    }

    return AppPageHeader(
      title: 'Daily Attendance',
      subtitle: dateSubtitle,
      isCompact: !isWide,
      badge: const AppLiveSyncBadge(),
      actions: const [
        CheckInRestrictionsToggle(),
      ],
    );
  }

  Widget _buildThursdayNotice(DateTime now) {
    final isThursday = now.weekday == DateTime.thursday;
    if (isThursday) return const SizedBox.shrink();

    final activeThursday = _getActiveThursday(now);
    final activeDateStr = DateFormat('EEEE, d MMM yyyy').format(activeThursday);

    int daysUntilThursday = (DateTime.thursday - now.weekday) % 7;
    if (daysUntilThursday <= 0) daysUntilThursday += 7;
    final nextThursday = now.add(Duration(days: daysUntilThursday));
    final nextDateStr = DateFormat('EEEE, d MMM yyyy').format(nextThursday);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withAlpha(18),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(70)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check-in is available on Thursday only. Showing attendance for $activeDateStr. Next session: $nextDateStr.',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics(
    BuildContext context,
    int totalMembersCount,
    int totalCheckIns,
    int memberCount,
    int substituteCount,
    int absentCount,
    double availableWidth,
  ) {
    final isMobile = availableWidth < 600;
    final cardHeight = isMobile ? 86.0 : 94.0;

    // 1. Total Active Members (from Members tab)
    final card1 = SizedBox(
      height: cardHeight,
      child: _HeroMetricCard(
        title: 'Total Active Members',
        value: '$totalMembersCount',
        icon: Icons.people_alt_rounded,
        accentColor: const Color(0xFF6366F1),
        isMobile: isMobile,
      ),
    );

    // 2. Total Check-Ins
    final card2 = SizedBox(
      height: cardHeight,
      child: _HeroMetricCard(
        title: 'Total Check-Ins',
        value: '$totalCheckIns',
        icon: Icons.groups_rounded,
        accentColor: AppColors.primary,
        isMobile: isMobile,
      ),
    );

    // 3. Members Checked In
    final card3 = SizedBox(
      height: cardHeight,
      child: _HeroMetricCard(
        title: 'Members',
        value: '$memberCount',
        icon: Icons.verified_user_rounded,
        accentColor: AppColors.success,
        isMobile: isMobile,
      ),
    );

    // 4. Substitutes Checked In
    final card4 = SizedBox(
      height: cardHeight,
      child: _HeroMetricCard(
        title: 'Substitutes',
        value: '$substituteCount',
        icon: Icons.camera_alt_rounded,
        accentColor: AppColors.warning,
        isMobile: isMobile,
      ),
    );

    // 5. Absent Members
    final card5 = SizedBox(
      height: cardHeight,
      child: _HeroMetricCard(
        title: 'Absent',
        value: '$absentCount',
        icon: Icons.person_off_rounded,
        accentColor: AppColors.error,
        isMobile: isMobile,
      ),
    );

    if (availableWidth >= 850) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 12),
          Expanded(child: card2),
          const SizedBox(width: 12),
          Expanded(child: card3),
          const SizedBox(width: 12),
          Expanded(child: card4),
          const SizedBox(width: 12),
          Expanded(child: card5),
        ],
      );
    }

    if (availableWidth >= 600) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 12),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: card3),
              const SizedBox(width: 12),
              Expanded(child: card4),
              const SizedBox(width: 12),
              Expanded(child: card5),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 12),
            Expanded(child: card2),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: card3),
            const SizedBox(width: 12),
            Expanded(child: card4),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: card5),
            const SizedBox(width: 12),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchFilterToolbar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    double availableWidth,
    int totalCount,
    int memberCount,
    int substituteCount,
    int absentCount,
    AdminDashboardFilterState filterState,
  ) {
    final isMobile = availableWidth < 600;

    final searchField = TextField(
      controller: _searchController,
      style: TextStyle(
        fontSize: isMobile ? 12.5 : 13.5,
      ),
      decoration: InputDecoration(
        hintText: isMobile ? 'Search name / phone...' : 'Search by Name or Phone...',
        hintStyle: TextStyle(
          fontSize: isMobile ? 12 : 13,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        prefixIcon: Icon(Icons.search_rounded, size: isMobile ? 17 : 20),
        prefixIconConstraints: isMobile
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, size: isMobile ? 16 : 18),
                padding: EdgeInsets.zero,
                constraints: isMobile
                    ? const BoxConstraints(minWidth: 28, minHeight: 28)
                    : const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () {
                  _searchController.clear();
                  ref
                      .read(adminDashboardFilterProvider.notifier)
                      .setSearchQuery('');
                },
              )
            : null,
        isDense: true,
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceDark
            : const Color(0xFFF1F5F9),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14,
          vertical: isMobile ? 8 : 12,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
      onChanged: (query) {
        ref.read(adminDashboardFilterProvider.notifier).setSearchQuery(query);
      },
    );

    final filterChips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FilterChip(
          label: 'All ($totalCount)',
          isSelected: filterState.filterType == AdminFilterType.all,
          onTap: () => ref
              .read(adminDashboardFilterProvider.notifier)
              .setFilterType(AdminFilterType.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Members ($memberCount)',
          isSelected: filterState.filterType == AdminFilterType.member,
          accentColor: AppColors.success,
          onTap: () => ref
              .read(adminDashboardFilterProvider.notifier)
              .setFilterType(AdminFilterType.member),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Substitutes ($substituteCount)',
          isSelected: filterState.filterType == AdminFilterType.substitute,
          accentColor: AppColors.warning,
          onTap: () => ref
              .read(adminDashboardFilterProvider.notifier)
              .setFilterType(AdminFilterType.substitute),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: 'Absent ($absentCount)',
          isSelected: filterState.filterType == AdminFilterType.absent,
          accentColor: AppColors.error,
          onTap: () => ref
              .read(adminDashboardFilterProvider.notifier)
              .setFilterType(AdminFilterType.absent),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Desktop Layout (>= 960px)
        if (width >= 960) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 16),
              filterChips,
            ],
          );
        }

        // Tablet & Mobile Layout (< 960px)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            searchField,
            const SizedBox(height: 10),
            // Horizontally scrollable filter pills with smooth trailing peek / fade shader
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.88, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      filterChips,
                      const SizedBox(width: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AsyncValue<List<CheckInSubmission>> allCheckInsAsync,
    List<CheckInSubmission> filteredRecords,
    double availableWidth,
  ) {
    if (allCheckInsAsync.isLoading && filteredRecords.isEmpty) {
      return const SingleChildScrollView(
        child: CheckInCardSkeletonList(count: 5),
      );
    }

    if (allCheckInsAsync.hasError && filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load check-ins',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              allCheckInsAsync.error.toString(),
              style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(checkInsStreamProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (filteredRecords.isEmpty) {
      return const AppEmptyView(
        message:
            'No Check-In Records Found.\nNew check-ins will appear here in real-time as members submit attendance.',
        icon: Icons.how_to_reg_outlined,
      );
    }

    // Spreadsheet / Table data view (Fixed Table Header, Only Data Rows scroll vertically)
    return _CheckInTableView(
      records: filteredRecords,
      employees: ref.watch(employeesStreamProvider).value,
      // Removed paginated state for live sync
      onRecordTap: (record) => _showDetailModal(context, record),
      onEditTap: (record) => _showEditCheckInDialog(context, record),
      onVerifyTap: _toggleVerifyCheckIn,
      scrollController: _scrollController,
      isEmbeddedInScroll: false,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.fullAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? effectiveAccent.withAlpha(45)
                    : (accentColor != null
                        ? effectiveAccent.withAlpha(25)
                        : const Color(0xFFEEF2FF)))
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              color: isSelected
                  ? effectiveAccent
                  : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: effectiveAccent,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark
                          ? (accentColor ?? const Color(0xFF818CF8))
                          : effectiveAccent)
                      : (isDark
                          ? AppColors.onSurfaceVariantDark
                          : AppColors.onSurfaceVariantLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standardized SaaS KPI Metric Card for Dashboard statistics
class _HeroMetricCard extends StatelessWidget {
  const _HeroMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.isMobile = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 8 : 10,
      ),
      borderRadius: AppRadius.mdAll,
      shadows: AppShadows.sm,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: isMobile ? 34 : 36,
            height: isMobile ? 34 : 36,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(isDark ? 35 : 20),
              borderRadius: AppRadius.mdAll,
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: isMobile ? 16 : 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick-preview dialog for attendee or substitute live photos.
void _showAttendeePhotoDialog({
  required BuildContext context,
  required Uint8List photoBytes,
  required String title,
  required String subtitle,
  String badgeLabel = 'Live Check-In Selfie',
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.lgAll,
          boxShadow: AppShadows.lg,
          border: Border.all(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(dialogCtx),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Image.memory(
                photoBytes,
                width: double.infinity,
                height: 320,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(isDark ? 35 : 20),
                borderRadius: AppRadius.fullAll,
                border: Border.all(
                  color: AppColors.warning.withAlpha(isDark ? 80 : 45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_rounded,
                    size: 13,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    badgeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Mobile-responsive attendee row component for small screen view (<600px).
class _MobileCheckInRow extends StatelessWidget {
  const _MobileCheckInRow({
    required this.index,
    required this.record,
    required this.isDark,
    required this.theme,
    required this.onRecordTap,
    required this.onEditTap,
    required this.onVerifyTap,
    this.employees,
  });

  final int index;
  final CheckInSubmission record;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onRecordTap;
  final VoidCallback onEditTap;
  final VoidCallback onVerifyTap;
  final List<Employee>? employees;

  @override
  Widget build(BuildContext context) {
    final photoBytes = ImageUtils.base64ToBytes(record.photoBase64);

    return InkWell(
      onTap: onRecordTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: [Photo/Initials] + [Name + Phone on secondary line] ... [Attendance Badge]
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAttendanceRecordAvatar(
                  record: record,
                  employees: employees,
                  size: 36,
                ),
                const SizedBox(width: 10),

                // Name & Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (record.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: AppColors.success,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 11,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatPhoneNumber(record.userPhone),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (record.type.isSubstitute &&
                          (record.substituteName?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.warning.withAlpha(26)
                                : const Color(0xFFFFFBEB),
                            borderRadius: AppRadius.fullAll,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.warning.withAlpha(70)
                                  : const Color(0xFFFDE68A),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (photoBytes != null)
                                InkWell(
                                  onTap: () => _showAttendeePhotoDialog(
                                    context: context,
                                    photoBytes: photoBytes,
                                    title: record.substituteName!,
                                    subtitle:
                                        'Substitute for ${record.userName}',
                                    badgeLabel: 'Substitute Live Photo',
                                  ),
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.warning.withAlpha(120),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.memory(
                                        photoBytes,
                                        width: 18,
                                        height: 18,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 12,
                                  color: AppColors.warning,
                                ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Sub: ${record.substituteName}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF92400E),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Attendance Type Badge
                AppAttendanceTypeBadge(type: record.type),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: GPS Status + Time + Actions
            Row(
              children: [
                if (record.type.isNotCheckedIn)
                  Text(
                    'Not checked in yet',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  )
                else ...[
                  if (record.type != CheckInType.absent) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatGpsDistance(record),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                  ],

                  // Time / Timestamp
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatTime(record.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: record.isEdited
                              ? const Color(0xFFD97706)
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                          fontWeight:
                              record.isEdited ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (record.isEdited) ...[
                        const SizedBox(width: 3),
                        const Text(
                          '(Edited)',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                const Spacer(),

                // Actions: Verify Button + Edit Button + Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        record.isVerified
                            ? Icons.verified_rounded
                            : Icons.verified_outlined,
                        size: 17,
                        color: record.isVerified
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant.withAlpha(160),
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      tooltip: record.isVerified
                          ? 'Verified'
                          : (record.type.isAbsent ? 'Verify Absence' : 'Verify'),
                      onPressed: onVerifyTap,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      tooltip: 'Edit',
                      onPressed: onEditTap,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows and Columns (Excel / Spreadsheet Data View) for check-in records.
class _CheckInTableView extends StatelessWidget {
  const _CheckInTableView({
    required this.records,
    required this.onRecordTap,
    required this.onEditTap,
    required this.onVerifyTap,
    this.scrollController,
    this.isEmbeddedInScroll = false,
    this.employees,
  });

  final List<CheckInSubmission> records;
  final void Function(CheckInSubmission) onRecordTap;
  final void Function(CheckInSubmission) onEditTap;
  final void Function(CheckInSubmission) onVerifyTap;
  final ScrollController? scrollController;
  final bool isEmbeddedInScroll;
  final List<Employee>? employees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final headerColor = isDark
        ? AppColors.surfaceVariantDark.withAlpha(120)
        : AppColors.surfaceVariantLight.withAlpha(160);

    const headerTextStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: Colors.grey,
    );

    Widget buildTableHeader() {
      return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withAlpha(40),
            ),
          ),
        ),
        child: const Row(
          children: [
            SizedBox(width: 50, child: Text('#', style: headerTextStyle)),
            Expanded(flex: 3, child: Text('MEMBER', style: headerTextStyle)),
            Expanded(flex: 2, child: Text('PHONE', style: headerTextStyle)),
            Expanded(
              flex: 2,
              child: Text('ATTENDANCE TYPE', style: headerTextStyle),
            ),
            Expanded(
              flex: 2,
              child: Text('SUBSTITUTE', style: headerTextStyle),
            ),
            Expanded(flex: 2, child: Text('GPS STATUS', style: headerTextStyle)),
            Expanded(flex: 2, child: Text('TIMESTAMP', style: headerTextStyle)),
            SizedBox(
              width: 90,
              child: Text(
                'ACTIONS',
                style: headerTextStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildDataRow(int index, CheckInSubmission record) {
      final rowNumber = index + 1;
      final isZebra = index.isOdd;
      final photoBytes = ImageUtils.base64ToBytes(record.photoBase64);
      final hasSubstitute = record.type.isSubstitute &&
          record.substituteName != null &&
          record.substituteName!.trim().isNotEmpty;

      return InkWell(
        onTap: () => onRecordTap(record),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isZebra
                ? (isDark
                    ? Colors.white.withAlpha(4)
                    : Colors.black.withAlpha(3))
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withAlpha(30),
              ),
            ),
          ),
          child: Row(
            children: [
              // #
              SizedBox(
                width: 50,
                child: Text(
                  rowNumber.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Member Photo + Name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _buildAttendanceRecordAvatar(
                      record: record,
                      employees: employees,
                      size: 32,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              record.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (record.isVerified) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: record.type.isAbsent
                                  ? 'Verified Absent'
                                  : 'Verified Attendee',
                              child: const Icon(
                                Icons.verified_rounded,
                                size: 15,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Phone
              Expanded(
                flex: 2,
                child: Text(
                  _formatPhoneNumber(record.userPhone),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Attendance Type Badge
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppAttendanceTypeBadge(type: record.type),
                ),
              ),

              // Substitute Column
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: hasSubstitute
                      ? Container(
                          padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.warning.withAlpha(26)
                                : const Color(0xFFFFFBEB),
                            borderRadius: AppRadius.fullAll,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.warning.withAlpha(70)
                                  : const Color(0xFFFDE68A),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Tooltip(
                                message: photoBytes != null
                                    ? 'Click to preview selfie'
                                    : 'Substitute attendee',
                                child: InkWell(
                                  borderRadius: AppRadius.fullAll,
                                  onTap: photoBytes != null
                                      ? () => _showAttendeePhotoDialog(
                                            context: context,
                                            photoBytes: photoBytes,
                                            title: record.substituteName!,
                                            subtitle:
                                                'Substitute for ${record.userName}',
                                            badgeLabel:
                                                'Substitute Live Photo',
                                          )
                                      : null,
                                  child: photoBytes != null
                                      ? Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.warning
                                                  .withAlpha(120),
                                              width: 1.2,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: Image.memory(
                                              photoBytes,
                                              width: 26,
                                              height: 26,
                                              cacheWidth: 52,
                                              cacheHeight: 52,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: AppColors.warning
                                                .withAlpha(40),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.warning
                                                  .withAlpha(90),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              record.substituteName!.trim()[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11.5,
                                                color: AppColors.warning,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  record.substituteName!,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF92400E),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                ),
              ),

              // GPS Distance / Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: (record.type == CheckInType.absent ||
                          record.type.isNotCheckedIn)
                      ? Text(
                          '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(120),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatGpsDistance(record),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Time (Date on top, Time below)
              Expanded(
                flex: 2,
                child: record.type.isNotCheckedIn
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(120),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatDate(record.timestamp),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: record.isEdited
                                      ? const Color(0xFFD97706)
                                      : (isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B)),
                                ),
                              ),
                              if (record.isEdited) ...[
                                const SizedBox(width: 4),
                                const Tooltip(
                                  message: 'Edited check-in record',
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 11.5,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(record.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: record.isEdited
                                  ? const Color(0xFFD97706).withAlpha(220)
                                  : theme.colorScheme.onSurfaceVariant
                                      .withAlpha(180),
                              fontWeight: record.isEdited
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),

              // Actions
              SizedBox(
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Verify Button
                    Semantics(
                      label: record.isVerified
                          ? 'Unverify attendance for ${record.userName}'
                          : 'Verify attendance for ${record.userName}',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          record.isVerified
                              ? Icons.verified_rounded
                              : Icons.verified_outlined,
                          size: 18,
                          color: record.isVerified
                              ? AppColors.success
                              : theme.colorScheme.onSurfaceVariant.withAlpha(160),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: record.isVerified
                            ? 'Verified (Click to unverify)'
                            : (record.type.isAbsent
                                ? 'Verify Absence'
                                : 'Verify Attendee Present'),
                        onPressed: () => onVerifyTap(record),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // Edit Details Button
                    Semantics(
                      label: 'Edit check-in details for ${record.userName}',
                      button: true,
                      child: IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: AppColors.primary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'Edit Check-In Details',
                        onPressed: () => onEditTap(record),
                      ),
                    ),
                    const SizedBox(width: 2),

                    // View Details Button
                    Semantics(
                      label: 'View details for ${record.userName}',
                      button: true,
                      child: IconButton(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 17,
                          color: AppColors.primary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: 'View Details',
                        onPressed: () => onRecordTap(record),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      elevation: 2,
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.mdAll,
      shadows: AppShadows.sm,
      child: ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Table Area (Fixed Header + Scrollable Data Rows only)
          if (isEmbeddedInScroll)
            LayoutBuilder(
              builder: (context, constraints) {
                final minTableWidth = constraints.maxWidth.isFinite &&
                        constraints.maxWidth > 1050
                    ? constraints.maxWidth
                    : 1050.0;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: minTableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildTableHeader(),
                        ...records.asMap().entries.map(
                              (entry) => buildDataRow(entry.key, entry.value),
                            ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final minTableWidth = constraints.maxWidth.isFinite &&
                          constraints.maxWidth > 1050
                      ? constraints.maxWidth
                      : 1050.0;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: SizedBox(
                      width: minTableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // FIXED HEADER ROW (Never scrolls vertically)
                          buildTableHeader(),

                          // SCROLLABLE DATA ROWS (Only rows scroll)
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: records.length,
                              itemBuilder: (context, index) =>
                                  buildDataRow(index, records[index]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

