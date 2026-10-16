import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/check_in_photo_image.dart';
import '../../../../core/widgets/member_photo.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../app_config/presentation/widgets/check_in_restrictions_toggle.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../../domain/attendance_edit_display.dart';
import '../../domain/attendance_substitute_absent_export.dart';
import '../../domain/substitute_check_in_mapping.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/attendance_overview_provider.dart';
import '../widgets/admin_dashboard_attendance_filter_chips.dart';
import '../widgets/admin_dashboard_hero_metric_card.dart';
import '../widgets/searchable_thursday_date_dialog.dart';

Widget _buildAttendanceRecordAvatar({
  required CheckInSubmission record,
  required List<Employee>? employees,
  required double size,
}) {
  final liveMember = employees == null || employees.isEmpty
      ? null
      : EmployeeLookup.forCheckIn(employees, record) ??
            (record.type.isSubstitute
                ? EmployeeLookup.forNamedMember(
                    employees,
                    record.substituteForMember,
                  )
                : null) ??
            (record.type.isSubstitute
                ? null
                : EmployeeLookup.byPhone(employees, record.userPhone)) ??
            EmployeeLookup.byName(employees, record.userName);

  Widget fallback() =>
      _buildFallbackRecordInitials(liveMember?.name ?? record.userName, size);

  // MEMBER column: member profile photo / initials only.
  // Never use substitute selfie (photoBase64) here.
  if (record.type.isSubstitute) {
    final photo = liveMember?.photoUrl?.trim() ?? '';
    if (liveMember != null && photo.isNotEmpty) {
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
    return fallback();
  }

  // Member / absent / not-checked-in: live profile photo when enrolled.
  if (liveMember != null &&
      (record.type.isMember ||
          record.type.isAbsent ||
          record.type.isNotCheckedIn)) {
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

  // Visitors (and members without profile photo): optional selfie payload.
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
  final initial = userName.trim().isNotEmpty
      ? userName.trim()[0].toUpperCase()
      : 'M';
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.primary.withAlpha(25),
      borderRadius: AppRadius.xsAll,
      border: Border.all(color: AppColors.primary.withAlpha(40)),
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
    'Dec',
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

/// GPS status label for Daily Attendance list tiles.
/// Always "On-Site" — never show km/m distance.
String _formatGpsDistance(CheckInSubmission _) => 'On-Site';

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

/// Empty / null phone → em dash (used for substitute phone when unset).
String _formatPhoneNumberOrDash(String? phone) {
  final trimmed = phone?.trim() ?? '';
  if (trimmed.isEmpty) return '—';
  return _formatPhoneNumber(trimmed);
}

/// GPS distance label for Daily Attendance detail modal.
/// Always "On-Site" — never show km/m distance.
String _formatGpsDistanceDetail(CheckInSubmission _) => 'On-Site';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  /// Unmapped Firestore check-in for [id], when present in the live stream.
  CheckInSubmission? _rawCheckInById(String id) {
    final all = ref.read(checkInsStreamProvider).value;
    if (all == null || id.isEmpty) return null;
    for (final row in all) {
      if (row.id == id) return row;
    }
    return null;
  }

  /// Covered member roster phone for a dashboard row (never substitute phone).
  String? _coveredMemberPhone(CheckInSubmission record) {
    final employees = ref.read(employeesStreamProvider).value ?? const [];
    final emp =
        EmployeeLookup.byId(employees, record.memberId) ??
        EmployeeLookup.byName(employees, record.userName) ??
        EmployeeLookup.forNamedMember(employees, record.substituteForMember);
    final phone = emp?.phone.trim() ?? '';
    return phone.isNotEmpty ? phone : null;
  }

  /// Prefer a real location from today's dashboard rows, else the app default.
  (String, String) _fallbackLocationFromDashboard() {
    final filterLoc = ref
        .read(adminDashboardFilterProvider)
        .selectedLocationId
        ?.trim();
    final rows = ref.read(baseDashboardRecordsProvider).value ?? const [];
    for (final row in rows) {
      final id = row.locationId.trim();
      final name = row.locationName.trim();
      if (id.isNotEmpty && name.isNotEmpty && name != '—') {
        if (filterLoc == null || filterLoc.isEmpty || id == filterLoc) {
          return (id, name);
        }
      }
    }
    for (final row in rows) {
      final id = row.locationId.trim();
      if (id.isNotEmpty) {
        final name = row.locationName.trim();
        return (
          id,
          name.isNotEmpty && name != '—' ? name : kDefaultAdminLocationName,
        );
      }
    }
    if (filterLoc != null && filterLoc.isNotEmpty) {
      return (filterLoc, kDefaultAdminLocationName);
    }
    return (kDefaultAdminLocationId, kDefaultAdminLocationName);
  }

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
                backgroundColor: newVerified
                    ? AppColors.success
                    : AppColors.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(newVerified ? 'Verify' : 'Unverify'),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    final fallback = _fallbackLocationFromDashboard();
    final stamped = DateTime.now();
    // Preserve substitute name/phone from the original check-in text fields
    // (raw Firestore doc), not a collapsed remapped dashboard row.
    final raw = _rawCheckInById(record.id);
    final memberPhone = _coveredMemberPhone(record);
    final attendee = record.type.isSubstitute
        ? resolveSubstituteAttendeeFields(
            displayed: record,
            raw: raw,
            coveredMemberName: record.userName,
            coveredMemberPhone: memberPhone,
          )
        : null;
    final updatedRecord = materializeAdminCheckInForWrite(
      record.copyWith(
        type: isNotCheckedIn ? CheckInType.member : record.type,
        isVerified: newVerified,
        clearVerificationMeta: !newVerified,
        verifiedAt: newVerified ? stamped : null,
        verifiedBy: newVerified ? 'Admin' : null,
        substituteName: (attendee?.name?.trim().isNotEmpty ?? false)
            ? attendee!.name!.trim()
            : record.substituteName,
        clearSubstituteName:
            record.type.isSubstitute &&
            (attendee?.name == null || attendee!.name!.trim().isEmpty) &&
            (record.substituteName == null ||
                record.substituteName!.trim().isEmpty),
        userPhone: (attendee != null && attendee.phone.isNotEmpty)
            ? attendee.phone
            : record.userPhone,
        substitutePhone: (attendee != null && attendee.phone.isNotEmpty)
            ? attendee.phone
            : (record.substitutePhone ?? record.userPhone),
        clearSubstitutePhone:
            record.type.isSubstitute &&
            (attendee == null || attendee.phone.isEmpty) &&
            record.userPhone.isEmpty &&
            (record.substitutePhone == null || record.substitutePhone!.isEmpty),
      ),
      newCheckInId: const Uuid().v4(),
      fallbackLocationId: fallback.$1,
      fallbackLocationName: fallback.$2,
    );

    try {
      final repository = ref.read(checkInRepositoryProvider);
      await repository.updateCheckIn(updatedRecord);
      ref
          .read(paginatedCheckInsProvider.notifier)
          .updateCheckInItem(updatedRecord, replaceId: record.id);

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
            backgroundColor: newVerified
                ? AppColors.success
                : const Color(0xFF475569),
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
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
    final employees =
        ref.read(employeesStreamProvider).value ?? const <Employee>[];
    final coveredEmployee =
        EmployeeLookup.byId(employees, record.memberId) ??
        EmployeeLookup.forCheckIn(employees, record) ??
        EmployeeLookup.byName(
          employees,
          record.type.isSubstitute
              ? record.substituteForMember
              : record.userName,
        );
    final coveredMemberId = coveredEmployee?.id ?? record.memberId;
    final coveredMemberName = (coveredEmployee?.name.trim().isNotEmpty ?? false)
        ? coveredEmployee!.name.trim()
        : (record.type.isSubstitute
              ? (record.substituteForMember?.trim().isNotEmpty ?? false)
                    ? record.substituteForMember!.trim()
                    : record.userName.trim()
              : record.userName.trim());

    // Prefill from original check-in text fields (raw doc), never the covered
    // member roster name/phone.
    final substituteAttendee = record.type.isSubstitute
        ? resolveSubstituteAttendeeFields(
            displayed: record,
            raw: _rawCheckInById(record.id),
            coveredMemberName: coveredMemberName,
            coveredMemberPhone: coveredEmployee?.phone,
          )
        : null;
    final initialName = record.type.isSubstitute
        ? ((substituteAttendee?.name?.trim().isNotEmpty ?? false)
              ? substituteAttendee!.name!.trim()
              : (record.substituteName?.trim() ?? ''))
        : (record.userName.trim().isNotEmpty
              ? record.userName.trim()
              : coveredMemberName);
    final nameController = TextEditingController(text: initialName);

    final initialPhone = record.type.isSubstitute
        ? ((substituteAttendee?.phone.isNotEmpty ?? false)
              ? substituteAttendee!.phone
              : (record.substitutePhone?.trim() ?? ''))
        : (record.userPhone.trim().isNotEmpty
              ? record.userPhone.trim()
              : (coveredEmployee?.phone.trim() ?? ''));
    final phoneController = TextEditingController(text: initialPhone);
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
          final isSubstituteType = selectedType.isSubstitute;

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
              onTap: () {
                setDialogState(() {
                  selectedType = type;
                  if (type == CheckInType.member ||
                      type == CheckInType.absent) {
                    final prevSubName =
                        substituteAttendee?.name?.trim() ??
                        record.substituteName?.trim();
                    if (nameController.text.trim().isEmpty ||
                        (prevSubName != null &&
                            nameController.text.trim() == prevSubName)) {
                      nameController.text = coveredMemberName;
                    }
                    final prevSubPhone =
                        substituteAttendee?.phone.trim() ??
                        record.substitutePhone?.trim();
                    if (phoneController.text.trim().isEmpty ||
                        (prevSubPhone != null &&
                            phoneController.text.trim() == prevSubPhone)) {
                      phoneController.text =
                          (coveredEmployee?.phone.trim().isNotEmpty ?? false)
                          ? coveredEmployee!.phone.trim()
                          : record.userPhone.trim();
                    }
                  } else if (type == CheckInType.substitute) {
                    if (nameController.text.trim() == coveredMemberName) {
                      final prevSubName =
                          (substituteAttendee?.name?.trim().isNotEmpty ?? false)
                          ? substituteAttendee!.name!.trim()
                          : (record.substituteName?.trim() ?? '');
                      nameController.text = prevSubName;
                      final prevSubPhone =
                          (substituteAttendee?.phone.isNotEmpty ?? false)
                          ? substituteAttendee!.phone
                          : (record.substitutePhone?.trim() ?? '');
                      phoneController.text = prevSubPhone;
                    }
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
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

                      if (selectedType == CheckInType.absent) ...[
                        Text(
                          'Member Name',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputDecorator(
                          decoration: buildDecoration(
                            hint: coveredMemberName,
                            prefixIcon: Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: iconColor,
                            ),
                          ),
                          child: Text(
                            coveredMemberName.isEmpty ? '—' : coveredMemberName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withAlpha(40),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This record will be marked as Absent for $coveredMemberName.',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        if (isSubstituteType) ...[
                          Text(
                            'Covered Member',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InputDecorator(
                            decoration: buildDecoration(
                              hint: coveredMemberName,
                              prefixIcon: Icon(
                                Icons.badge_outlined,
                                size: 20,
                                color: iconColor,
                              ),
                            ),
                            child: Text(
                              coveredMemberName.isEmpty
                                  ? '—'
                                  : coveredMemberName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Full Name / Substitute Name
                        Text(
                          isSubstituteType ? 'Substitute Name' : 'Member Name',
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
                            hint: isSubstituteType
                                ? 'Enter substitute attendee name'
                                : (coveredMemberName.isNotEmpty
                                      ? coveredMemberName
                                      : 'Enter member name'),
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                              color: iconColor,
                            ),
                          ),
                          validator: (val) {
                            if (selectedType == CheckInType.absent ||
                                selectedType == CheckInType.member) {
                              return null;
                            }
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter substitute name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Phone Number
                        Text(
                          isSubstituteType
                              ? 'Substitute Phone'
                              : 'Phone Number',
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
                            hint: isSubstituteType
                                ? 'Enter substitute phone number'
                                : 'Enter phone number',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              size: 20,
                              color: iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

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
                      const SizedBox(height: 22),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              style: OutlinedButton.styleFrom(
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
                                final fallback =
                                    _fallbackLocationFromDashboard();
                                final nameToSave =
                                    selectedType == CheckInType.absent
                                    ? coveredMemberName
                                    : (nameController.text.trim().isNotEmpty
                                          ? nameController.text.trim()
                                          : coveredMemberName);
                                final phoneToSave =
                                    selectedType == CheckInType.absent
                                    ? (coveredEmployee?.phone ??
                                          record.userPhone)
                                    : (phoneController.text.trim().isNotEmpty
                                          ? phoneController.text.trim()
                                          : (coveredEmployee?.phone ??
                                                record.userPhone));
                                final updated = prepareAdminEditedCheckIn(
                                  original: record,
                                  selectedType: selectedType,
                                  nameField: nameToSave,
                                  phoneField: phoneToSave,
                                  venueField: venueController.text,
                                  coveredMemberName: coveredMemberName,
                                  coveredMemberId: coveredMemberId,
                                  isVerified: isVerified,
                                  newCheckInId: const Uuid().v4(),
                                  fallbackLocationId: fallback.$1,
                                  fallbackLocationName: fallback.$2,
                                );

                                Navigator.pop(dialogCtx);

                                try {
                                  final repo = ref.read(
                                    checkInRepositoryProvider,
                                  );
                                  await repo.updateCheckIn(updated);
                                  ref
                                      .read(paginatedCheckInsProvider.notifier)
                                      .updateCheckInItem(
                                        updated,
                                        replaceId: record.id,
                                      );

                                  if (mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
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
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
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
    final raw = _rawCheckInById(record.id);
    final memberPhone = _coveredMemberPhone(record);
    final substituteAttendee = record.type.isSubstitute
        ? resolveSubstituteAttendeeFields(
            displayed: record,
            raw: raw,
            coveredMemberName: record.userName,
            coveredMemberPhone: memberPhone,
          )
        : null;

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
              if (photoBytes != null ||
                  (record.type.isSubstitute && _checkInHasPhoto(record))) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadius.mdAll,
                          child: photoBytes != null
                              ? Image.memory(
                                  photoBytes,
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                )
                              : CheckInPhotoImage(
                                  submission: record,
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
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

          _DetailItem(
            label: record.type.isSubstitute ? 'Member Name' : 'Name',
            value: record.userName,
          ),
          if (record.type.isSubstitute)
            _DetailItem(
              label: 'Substitute Name',
              value: (substituteAttendee?.name?.trim().isNotEmpty ?? false)
                  ? substituteAttendee!.name!.trim()
                  : ((record.substituteName?.trim().isNotEmpty ?? false)
                        ? record.substituteName!.trim()
                        : '—'),
            ),
          _DetailItem(
            label: record.type.isSubstitute
                ? 'Substitute Phone'
                : 'Phone Number',
            value: record.type.isSubstitute
                ? _formatPhoneNumberOrDash(
                    (substituteAttendee?.phone.isNotEmpty ?? false)
                        ? substituteAttendee!.phone
                        : record.substitutePhone,
                  )
                : _formatPhoneNumberOrDash(record.userPhone),
          ),
          _DetailItem(label: 'Attendance Type', value: record.type.displayName),
          _DetailItem(label: 'Venue', value: record.locationName),
          _DetailItem(
            label: 'GPS Distance',
            value:
                (record.type == CheckInType.absent ||
                    record.type.isNotCheckedIn)
                ? '-'
                : _formatGpsDistanceDetail(record),
          ),
          _DetailItem(
            label: 'GPS Coordinates',
            value:
                (record.type == CheckInType.absent ||
                    record.type.isNotCheckedIn)
                ? '-'
                : '${record.userLatitude.toStringAsFixed(4)}, ${record.userLongitude.toStringAsFixed(4)}',
          ),
          _DetailItem(
            label: 'Timestamp',
            value: attendanceDetailTimestampLabel(record),
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
                        : (record.type.isAbsent
                              ? 'Verify Absent'
                              : 'Verify Present'),
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
            child: SingleChildScrollView(child: buildDetailContent(sheetCtx)),
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

    final dashboardRecords = baseRecords
        .where((r) => !r.type.isVisitor)
        .toList();
    final totalCount = dashboardRecords.length;
    final memberCount = dashboardRecords.where((r) => r.type.isMember).length;
    final substituteCount = dashboardRecords
        .where((r) => r.type.isSubstitute)
        .length;
    final absentCount = dashboardRecords.where((r) => r.type.isAbsent).length;
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
    final employeesAsync = ref.watch(employeesStreamProvider);
    final baseRecordsAsync = ref.watch(baseDashboardRecordsProvider);
    final waiting =
        (allCheckInsAsync.isLoading ||
            employeesAsync.isLoading ||
            baseRecordsAsync.isLoading) &&
        filteredRecords.isEmpty;
    final loadError = allCheckInsAsync.hasError
        ? allCheckInsAsync.error
        : (employeesAsync.hasError
              ? employeesAsync.error
              : (baseRecordsAsync.hasError ? baseRecordsAsync.error : null));

    if (waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CheckInCardSkeletonList(count: 3),
      );
    }

    if (loadError != null && filteredRecords.isEmpty) {
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
              loadError.toString(),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(checkInsStreamProvider);
                ref.invalidate(employeesStreamProvider);
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
              Row(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(width: 2),
                  _buildMemberNameSortArrow(),
                ],
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
                  rawCheckIn: _rawCheckInById(record.id),
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

  DateTime _defaultSessionDate(DateTime now) {
    return defaultAttendanceSessionDate(
      now,
      dateRestrictionEnabled: ref.watch(dateRestrictionEnabledProvider),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    bool isWide,
    int totalCount,
    DateTime now,
    AdminDashboardFilterState filterState,
  ) {
    final viewingDate = filterState.selectedDate ?? _defaultSessionDate(now);
    final viewingDateStr = DateFormat('EEEE, d MMM yyyy').format(viewingDate);
    final dateRestrictionEnabled = ref.watch(dateRestrictionEnabledProvider);
    final isLiveToday =
        filterState.selectedDate == null &&
        viewingDate.year == now.year &&
        viewingDate.month == now.month &&
        viewingDate.day == now.day;
    final dateSubtitle = !dateRestrictionEnabled
        ? (isLiveToday
              ? 'Live attendance for today, $viewingDateStr.'
              : 'Attendance records for $viewingDateStr.')
        : isLiveToday && now.weekday == DateTime.thursday
        ? 'Live attendance for today, $viewingDateStr.'
        : 'Attendance records for $viewingDateStr.';

    return AppPageHeader(
      title: 'Daily Attendance',
      subtitle: dateSubtitle,
      isCompact: !isWide,
      badge: const AppLiveSyncBadge(),
      actions: const [CheckInRestrictionsToggle()],
    );
  }

  Widget _buildSessionDateDropdown(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AdminDashboardFilterState filterState,
    DateTime now,
  ) {
    final allThursdays = ref.watch(allThursdayDatesProvider);
    final viewingDate = filterState.selectedDate ?? _defaultSessionDate(now);
    final isCustom = filterState.selectedDate != null;
    final displayText = DateFormat('EEE, dd MMM yyyy').format(viewingDate);

    return Builder(
      builder: (btnContext) {
        return InkWell(
          onTap: () {
            showSearchableThursdayDateDropdown(
              context: btnContext,
              isDark: isDark,
              selectedDate: viewingDate,
              allThursdays: allThursdays,
              onDateSelected: (date) {
                ref
                    .read(adminDashboardFilterProvider.notifier)
                    .setSelectedDate(
                      date == null
                          ? null
                          : DateTime(date.year, date.month, date.day),
                    );
              },
            );
          },
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isCustom
                  ? AppColors.primary.withAlpha(isDark ? 40 : 20)
                  : (isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCustom
                    ? AppColors.primary.withAlpha(120)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: isCustom
                      ? AppColors.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isCustom
                        ? AppColors.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadSubstituteAbsentTxt() async {
    final filterState = ref.read(adminDashboardFilterProvider);
    final sessionDate =
        filterState.selectedDate ??
        defaultAttendanceSessionDate(
          DateTime.now(),
          dateRestrictionEnabled: ref.read(dateRestrictionEnabledProvider),
        );
    final records = ref.read(baseDashboardRecordsProvider).value ?? [];
    final filename = attendanceExportTxtFilename(sessionDate);
    final content = buildSubstituteAbsentAttendanceTxt(records: records);

    try {
      await FileDownloadHelper.downloadTxt(content, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded $filename'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSubstituteAbsentDownloadButton(ThemeData theme, bool isDark) {
    return Tooltip(
      message: 'Download Substitute & Absent (.txt)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _downloadSubstituteAbsentTxt,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sub / Absent',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberNameSortArrow({Color? inactiveColor}) {
    final filterState = ref.watch(adminDashboardFilterProvider);
    final sortMode = filterState.sortMode;
    final isAlphabetical = sortMode == AdminDashboardSortMode.alphabetical;
    final theme = Theme.of(context);

    return PopupMenuButton<AdminDashboardSortMode>(
      tooltip: 'Sort by member name',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 28),
      initialValue: sortMode,
      onSelected: (mode) {
        ref.read(adminDashboardFilterProvider.notifier).setSortMode(mode);
      },
      itemBuilder: (context) => [
        for (final mode in AdminDashboardSortMode.values)
          PopupMenuItem(
            value: mode,
            height: 40,
            child: Text(
              mode.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: mode == sortMode
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: mode == sortMode
                    ? AppColors.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
      child: Icon(
        Icons.arrow_drop_down_rounded,
        size: 20,
        color: isAlphabetical
            ? AppColors.primary
            : (inactiveColor ?? Colors.grey),
      ),
    );
  }

  Widget _buildThursdayNotice(DateTime now) {
    final dateRestrictionEnabled = ref.watch(dateRestrictionEnabledProvider);
    // When date restriction is OFF, everyday check-in is allowed — no banner.
    if (!dateRestrictionEnabled) return const SizedBox.shrink();

    final isThursday = now.weekday == DateTime.thursday;
    if (isThursday) return const SizedBox.shrink();

    final activeThursday = defaultAttendanceSessionDate(
      now,
      dateRestrictionEnabled: true,
    );
    final activeDateStr = DateFormat('EEEE, d MMM yyyy').format(activeThursday);

    final today = DateTime(now.year, now.month, now.day);
    var daysUntilThursday = (DateTime.thursday - today.weekday) % 7;
    if (daysUntilThursday <= 0) daysUntilThursday += 7;
    final nextThursday = today.add(Duration(days: daysUntilThursday));
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
      child: AdminDashboardHeroMetricCard(
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
      child: AdminDashboardHeroMetricCard(
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
      child: AdminDashboardHeroMetricCard(
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
      child: AdminDashboardHeroMetricCard(
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
      child: AdminDashboardHeroMetricCard(
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
      style: TextStyle(fontSize: isMobile ? 12.5 : 13.5),
      decoration: InputDecoration(
        hintText: isMobile
            ? 'Search name / phone...'
            : 'Search by Name or Phone...',
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
        fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
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
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: (query) {
        ref.read(adminDashboardFilterProvider.notifier).setSearchQuery(query);
      },
    );

    final now = DateTime.now();
    final sessionDateDropdown = _buildSessionDateDropdown(
      context,
      theme,
      isDark,
      filterState,
      now,
    );

    final exportButton = _buildSubstituteAbsentDownloadButton(theme, isDark);

    final filterChips = AdminDashboardAttendanceFilterChips(
      filterType: filterState.filterType,
      totalCount: totalCount,
      memberCount: memberCount,
      substituteCount: substituteCount,
      absentCount: absentCount,
      onFilterTypeChanged: (type) =>
          ref.read(adminDashboardFilterProvider.notifier).setFilterType(type),
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
              const SizedBox(width: 12),
              sessionDateDropdown,
              const SizedBox(width: 8),
              exportButton,
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
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [sessionDateDropdown, exportButton],
              ),
            ),
            const SizedBox(height: 10),
            // Horizontally scrollable filter pills with smooth trailing peek / fade shader
            ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.white, Colors.transparent],
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
                    children: [filterChips, const SizedBox(width: 24)],
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
    final employeesAsync = ref.watch(employeesStreamProvider);
    final baseRecordsAsync = ref.watch(baseDashboardRecordsProvider);
    final waiting =
        (allCheckInsAsync.isLoading ||
            employeesAsync.isLoading ||
            baseRecordsAsync.isLoading) &&
        filteredRecords.isEmpty;
    final loadError = allCheckInsAsync.hasError
        ? allCheckInsAsync.error
        : (employeesAsync.hasError
              ? employeesAsync.error
              : (baseRecordsAsync.hasError ? baseRecordsAsync.error : null));

    if (waiting) {
      return const SingleChildScrollView(
        child: CheckInCardSkeletonList(count: 5),
      );
    }

    if (loadError != null && filteredRecords.isEmpty) {
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
              loadError.toString(),
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.onSurfaceDark
                    : AppColors.onSurfaceLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(checkInsStreamProvider);
                ref.invalidate(employeesStreamProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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

    // Snapshot raw check-ins for substitute name/phone resolution during build.
    final rawCheckIns = ref.watch(checkInsStreamProvider).value ?? const [];
    final rawById = <String, CheckInSubmission>{
      for (final row in rawCheckIns) row.id: row,
    };

    // Spreadsheet / Table data view (Fixed Table Header, Only Data Rows scroll vertically)
    return _CheckInTableView(
      records: filteredRecords,
      employees: ref.watch(employeesStreamProvider).value,
      // Removed paginated state for live sync
      onRecordTap: (record) => _showDetailModal(context, record),
      onEditTap: (record) => _showEditCheckInDialog(context, record),
      onVerifyTap: _toggleVerifyCheckIn,
      rawCheckInById: (id) => rawById[id],
      scrollController: _scrollController,
      isEmbeddedInScroll: false,
    );
  }
}

bool _checkInHasPhoto(CheckInSubmission record) {
  return record.hasPhoto ||
      (record.photoPath?.trim().isNotEmpty ?? false) ||
      (record.photoBase64?.trim().isNotEmpty ?? false);
}

Widget _substituteInitialAvatar(String subName, {required double size}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.warning.withAlpha(40),
      shape: BoxShape.circle,
      border: Border.all(
        color: AppColors.warning.withAlpha(90),
        width: 1.0,
      ),
    ),
    child: Center(
      child: Text(
        subName.trim().isNotEmpty ? subName.trim()[0].toUpperCase() : 'S',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
          color: AppColors.warning,
        ),
      ),
    ),
  );
}

/// Quick-preview dialog for attendee or substitute live photos.
///
/// Prefers inline [photoBytes] when present; otherwise loads Storage via
/// [submission] (lean list rows only have `photo_path` / `has_photo`).
void _showAttendeePhotoDialog({
  required BuildContext context,
  Uint8List? photoBytes,
  CheckInSubmission? submission,
  required String title,
  required String subtitle,
  String badgeLabel = 'Live Check-In Selfie',
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bytes = photoBytes;
  final hasInline = bytes != null && bytes.isNotEmpty;
  final canLoadStorage =
      submission != null && _checkInHasPhoto(submission);

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
              child: hasInline
                  ? Image.memory(
                      bytes,
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.cover,
                    )
                  : canLoadStorage
                  ? CheckInPhotoImage(
                      submission: submission,
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.cover,
                      placeholder: const SizedBox(
                        height: 320,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : const SizedBox(
                      height: 320,
                      child: Center(child: Icon(Icons.person_outline)),
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
    this.rawCheckIn,
  });

  final int index;
  final CheckInSubmission record;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onRecordTap;
  final VoidCallback onEditTap;
  final VoidCallback onVerifyTap;
  final List<Employee>? employees;
  final CheckInSubmission? rawCheckIn;

  @override
  Widget build(BuildContext context) {
    final photoBytes = ImageUtils.base64ToBytes(record.photoBase64);
    final hasStoredPhoto = _checkInHasPhoto(record);
    final coveredEmp =
        EmployeeLookup.byId(employees ?? const [], record.memberId) ??
        EmployeeLookup.byName(employees ?? const [], record.userName);
    final rosterPhone = coveredEmp?.phone.trim() ?? '';
    final substituteAttendee = record.type.isSubstitute
        ? resolveSubstituteAttendeeFields(
            displayed: record,
            raw: rawCheckIn,
            coveredMemberName: record.userName,
            coveredMemberPhone: rosterPhone.isNotEmpty ? rosterPhone : null,
          )
        : null;
    // Name only — never use userPhone (often the member after remap).
    final subLabel =
        (substituteAttendee?.displayLabel?.trim().isNotEmpty ?? false)
        ? substituteAttendee!.displayLabel!.trim()
        : (record.substituteName?.trim() ?? '');
    final subPhone = (substituteAttendee?.phone.isNotEmpty ?? false)
        ? substituteAttendee!.phone
        : (record.substitutePhone?.trim() ?? '');
    final memberPhone = () {
      if (!record.type.isSubstitute) return record.userPhone;
      return rosterPhone.isNotEmpty ? rosterPhone : record.userPhone;
    }();

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
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(
                              180,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatPhoneNumber(memberPhone),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (record.type.isSubstitute &&
                          (subLabel.isNotEmpty || hasStoredPhoto)) ...[
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
                              if (hasStoredPhoto)
                                InkWell(
                                  onTap: () => _showAttendeePhotoDialog(
                                    context: context,
                                    photoBytes: photoBytes,
                                    submission: record,
                                    title: subLabel.isNotEmpty
                                        ? subLabel
                                        : 'Substitute',
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
                                      child: photoBytes != null
                                          ? Image.memory(
                                              photoBytes,
                                              width: 18,
                                              height: 18,
                                              fit: BoxFit.cover,
                                            )
                                          : CheckInPhotoImage(
                                              submission: record,
                                              width: 18,
                                              height: 18,
                                              fit: BoxFit.cover,
                                              placeholder:
                                                  _substituteInitialAvatar(
                                                subLabel,
                                                size: 18,
                                              ),
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
                                  'Sub: ${subLabel.isNotEmpty ? subLabel : (subPhone.isNotEmpty ? _formatPhoneNumber(subPhone) : '—')}',
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
                        _formatTime(attendanceDisplayClock(record)),
                        style: TextStyle(
                          fontSize: 11,
                          color: record.isEdited
                              ? const Color(0xFFD97706)
                              : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          fontWeight: record.isEdited
                              ? FontWeight.w600
                              : FontWeight.w500,
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
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      tooltip: record.isVerified
                          ? 'Verified'
                          : (record.type.isAbsent
                                ? 'Verify Absence'
                                : 'Verify'),
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
                      constraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
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
class _CheckInTableView extends ConsumerWidget {
  const _CheckInTableView({
    required this.records,
    required this.onRecordTap,
    required this.onEditTap,
    required this.onVerifyTap,
    required this.rawCheckInById,
    this.scrollController,
    this.isEmbeddedInScroll = false,
    this.employees,
  });

  final List<CheckInSubmission> records;
  final void Function(CheckInSubmission) onRecordTap;
  final void Function(CheckInSubmission) onEditTap;
  final void Function(CheckInSubmission) onVerifyTap;
  final CheckInSubmission? Function(String id) rawCheckInById;
  final ScrollController? scrollController;
  final bool isEmbeddedInScroll;
  final List<Employee>? employees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sortMode = ref.watch(adminDashboardFilterProvider).sortMode;
    final isAlphabetical = sortMode == AdminDashboardSortMode.alphabetical;

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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withAlpha(40)),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 50, child: Text('#', style: headerTextStyle)),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Text('MEMBER', style: headerTextStyle),
                  const SizedBox(width: 2),
                  PopupMenuButton<AdminDashboardSortMode>(
                    tooltip: 'Sort by member name',
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 28),
                    initialValue: sortMode,
                    onSelected: (mode) {
                      ref
                          .read(adminDashboardFilterProvider.notifier)
                          .setSortMode(mode);
                    },
                    itemBuilder: (context) => [
                      for (final mode in AdminDashboardSortMode.values)
                        PopupMenuItem(
                          value: mode,
                          height: 40,
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: mode == sortMode
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: mode == sortMode
                                  ? AppColors.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                    ],
                    child: Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: isAlphabetical ? AppColors.primary : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              flex: 2,
              child: Text('PHONE', style: headerTextStyle),
            ),
            const Expanded(
              flex: 2,
              child: Text('ATTENDANCE TYPE', style: headerTextStyle),
            ),
            const Expanded(
              flex: 2,
              child: Text('SUBSTITUTE', style: headerTextStyle),
            ),
            const Expanded(
              flex: 2,
              child: Text('GPS STATUS', style: headerTextStyle),
            ),
            const Expanded(
              flex: 2,
              child: Text('TIMESTAMP', style: headerTextStyle),
            ),
            const SizedBox(
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
      final hasStoredPhoto = _checkInHasPhoto(record);
      final raw = rawCheckInById(record.id);
      final coveredEmp =
          EmployeeLookup.byId(employees ?? const [], record.memberId) ??
          EmployeeLookup.byName(employees ?? const [], record.userName);
      final rosterPhone = coveredEmp?.phone.trim() ?? '';
      final substituteAttendee = record.type.isSubstitute
          ? resolveSubstituteAttendeeFields(
              displayed: record,
              raw: raw,
              coveredMemberName: record.userName,
              coveredMemberPhone: rosterPhone.isNotEmpty ? rosterPhone : null,
            )
          : null;
      // Name / dedicated substitute phone only — never member userPhone.
      final subName =
          (substituteAttendee?.displayLabel?.trim().isNotEmpty ?? false)
          ? substituteAttendee!.displayLabel!.trim()
          : (record.substituteName?.trim() ?? '');
      final subPhone = (substituteAttendee?.phone.isNotEmpty ?? false)
          ? substituteAttendee!.phone
          : (record.substitutePhone?.trim() ?? '');
      final hasSubstitute =
          record.type.isSubstitute &&
          (subName.isNotEmpty || subPhone.isNotEmpty || hasStoredPhoto);
      // Member column phone = roster phone; substitute phone lives in SUBSTITUTE.
      final memberPhone = () {
        if (!record.type.isSubstitute) return record.userPhone;
        return rosterPhone.isNotEmpty ? rosterPhone : record.userPhone;
      }();

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
              bottom: BorderSide(color: theme.dividerColor.withAlpha(30)),
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

              // Phone (member roster for substitute rows)
              Expanded(
                flex: 2,
                child: Text(
                  _formatPhoneNumber(memberPhone),
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

              // Substitute Column — name/phone from check-in text fields + selfie
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: hasSubstitute
                        ? Container(
                            padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
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
                              children: [
                                Tooltip(
                                  message: hasStoredPhoto
                                      ? 'Click to preview selfie'
                                      : 'Substitute attendee',
                                  child: InkWell(
                                    borderRadius: AppRadius.fullAll,
                                    onTap: hasStoredPhoto
                                        ? () => _showAttendeePhotoDialog(
                                            context: context,
                                            photoBytes: photoBytes,
                                            submission: record,
                                            title: subName.isNotEmpty
                                                ? subName
                                                : 'Substitute',
                                            subtitle:
                                                'Substitute for ${record.userName}',
                                            badgeLabel: 'Substitute Live Photo',
                                          )
                                        : null,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.warning
                                              .withAlpha(120),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: hasStoredPhoto
                                            ? (photoBytes != null
                                                  ? Image.memory(
                                                      photoBytes,
                                                      width: 22,
                                                      height: 22,
                                                      cacheWidth: 44,
                                                      cacheHeight: 44,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : CheckInPhotoImage(
                                                      submission: record,
                                                      width: 22,
                                                      height: 22,
                                                      fit: BoxFit.cover,
                                                      placeholder: _substituteInitialAvatar(
                                                        subName,
                                                        size: 22,
                                                      ),
                                                    ))
                                            : _substituteInitialAvatar(
                                                subName,
                                                size: 22,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    subName.isNotEmpty
                                        ? subName
                                        : (subPhone.isNotEmpty
                                              ? _formatPhoneNumber(subPhone)
                                              : '—'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                      height: 1.15,
                                      color: isDark
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFF92400E),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
              ),

              // GPS Distance / Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      (record.type == CheckInType.absent ||
                          record.type.isNotCheckedIn)
                      ? Text(
                          '—',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(
                              120,
                            ),
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
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(
                              120,
                            ),
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
                                _formatDate(attendanceDisplayDate(record)),
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
                            _formatTime(attendanceDisplayClock(record)),
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
                              : theme.colorScheme.onSurfaceVariant.withAlpha(
                                  160,
                                ),
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
                  final minTableWidth =
                      constraints.maxWidth.isFinite &&
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
                    final minTableWidth =
                        constraints.maxWidth.isFinite &&
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
