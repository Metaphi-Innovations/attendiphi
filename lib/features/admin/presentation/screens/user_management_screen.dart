import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/biometrics/biometrics_provider.dart';
import '../../../../core/biometrics/face_matching_config.dart';
import '../../../../core/biometrics/web_face_embedder.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_filter_dropdown.dart';
import '../../../../core/widgets/app_metric_card.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/member_photo.dart';
import '../../../../core/widgets/web_camera_capture_dialog.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_scope_provider.dart';
import '../providers/member_list_filters.dart';
import '../providers/visitor_management_provider.dart';

/// Member / Employee Management Screen managing registered attendees for check-in.
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  MemberSortOption _sortOption = MemberSortOption.mostVisitors;
  MemberStatusFilter _statusFilter = MemberStatusFilter.all;

  /// Force roster streams to refresh immediately after mutations (don't wait
  /// for Realtime / reconcile poll).
  void _invalidateMemberStreams() {
    ref.invalidate(employeesStreamProvider);
    ref.invalidate(publicMembersStreamProvider);
    ref.invalidate(faceVerificationCandidatesProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      AppColors.primary, // Indigo
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFFD97706), // Amber
      const Color(0xFF7C3AED), // Purple
      const Color(0xFFE11D48), // Rose
      const Color(0xFF059669), // Emerald
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

  Widget _buildMemberAvatar({
    required Employee member,
    required double size,
    required Color avatarColor,
    required String initials,
    double fontSize = 12,
    BorderRadius? borderRadius,
  }) {
    final photo = member.photoUrl;
    final effectiveBorderRadius = borderRadius ?? AppRadius.xsAll;

    Widget buildFallback() {
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            color: avatarColor,
          ),
        ),
      );
    }

    Widget? imageWidget;
    if (photo != null && photo.trim().isNotEmpty) {
      imageWidget = MemberPhoto(
        member: member,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => buildFallback(),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatarColor.withAlpha(30),
        borderRadius: effectiveBorderRadius,
        border: Border.all(color: avatarColor.withAlpha(70), width: 1),
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: imageWidget ?? buildFallback(),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final local = dt.toLocal();
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
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    return '$day $month $year';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showAddEditMemberDialog({Employee? existingMember}) {
    final isEditing = existingMember != null;
    final nameController = TextEditingController(
      text: existingMember?.name ?? '',
    );
    final phoneController = TextEditingController(
      text: existingMember?.phone ?? '',
    );
    final emailController = TextEditingController(
      text: existingMember?.email ?? '',
    );
    final selectedRole = existingMember?.role.isNotEmpty == true
        ? existingMember!.role
        : 'Member';
    final isActive = existingMember?.isActive ?? true;
    var isSubmitting = false;
    String? submitError;
    final formKey = GlobalKey<FormState>();

    List<double>? enrolledEmbedding = existingMember?.faceEmbedding;
    List<List<double>>? enrolledTemplates = existingMember?.faceTemplates;
    String? enrolledPhotoUrl = existingMember?.photoUrl;
    Uint8List? enrolledImageBytes;
    File? enrolledImageFile;
    bool isProcessingFace = false;
    String? faceStatusMessage =
        existingMember != null &&
            existingMember.faceEnrolled &&
            !existingMember.hasSfaceTemplates
        ? 'This member needs a live web re-enrollment (camera) before face check-in will work in the browser.'
        : null;

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
          final labelColor = isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF475569);
          final iconColor = isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B);

          Future<void> pickFacePhoto(ImageSource source) async {
            try {
              Uint8List? rawBytes;
              File? photoFile;
              List<Uint8List>? burstFrames;

              if (source == ImageSource.camera && kIsWeb) {
                burstFrames = await WebCameraCaptureHelper.captureBurstPhotos(
                  context,
                  count: 4,
                  intervalMs: 400,
                  waitForFace: true,
                  allowGallery: false,
                  poseGuides: const [
                    'Look at the camera',
                    'Turn slightly left',
                    'Turn slightly right',
                    'Look at the camera',
                  ],
                );
                if (burstFrames == null || burstFrames.isEmpty) return;
                rawBytes = burstFrames.first;
              } else if (kIsWeb) {
                throw Exception(
                  'Face registration needs a live camera capture of 3–5 samples. Please use Take Photo.',
                );
              } else {
                final picker = ImagePicker();
                final photo = await picker.pickImage(
                  source: source,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                  preferredCameraDevice: CameraDevice.front,
                );
                if (photo == null) return;
                rawBytes = await photo.readAsBytes();
                if (!kIsWeb) {
                  photoFile = File(photo.path);
                }
              }

              setDialogState(() {
                isProcessingFace = true;
                faceStatusMessage =
                    'Extracting and validating SFace biometrics...';
              });

              if (kIsWeb) {
                final validTemplates = <List<double>>[];
                final candidateFrames =
                    (burstFrames != null && burstFrames.isNotEmpty)
                    ? burstFrames
                    : [rawBytes];

                for (final frameBytes in candidateFrames) {
                  final base64Photo = ImageUtils.bytesToBase64(frameBytes);
                  final frame = await validateAndExtractFaceFrameWeb(
                    base64Photo,
                    forEnrollment: true,
                  );
                  if (frame.isValid &&
                      frame.meetsQuality(forEnrollment: true) &&
                      frame.embedding != null &&
                      frame.embedding!.length == 128) {
                    validTemplates.add(List<double>.from(frame.embedding!));
                  }
                }

                if (validTemplates.isEmpty) {
                  throw Exception(
                    'No face detected. Please position your face in front of the camera.',
                  );
                }

                final matchingService = ref.read(faceMatchingServiceProvider);
                final pruned = matchingService.pruneEnrollmentOutliers(
                  validTemplates,
                );
                if (!matchingService.isEnrollmentTemplateSetValid(pruned)) {
                  throw Exception(
                    pruned.length <
                            FaceMatchingConfig.minimumEnrollmentTemplates
                        ? 'Need at least ${FaceMatchingConfig.minimumEnrollmentTemplates} clear frames. Please keep your face in the oval in good lighting and try again.'
                        : 'Could not get a consistent set of face samples. Please retry the live capture.',
                  );
                }

                final decoded = img.decodeImage(rawBytes);
                Uint8List compressedJpg = rawBytes;
                if (decoded != null) {
                  final oriented = img.bakeOrientation(decoded);
                  final resized = oriented.width > 600 || oriented.height > 600
                      ? img.copyResize(oriented, width: 600)
                      : oriented;
                  compressedJpg = Uint8List.fromList(
                    img.encodeJpg(resized, quality: 80),
                  );
                }
                final base64Photo = ImageUtils.bytesToBase64(compressedJpg);

                setDialogState(() {
                  enrolledTemplates = pruned;
                  enrolledEmbedding = pruned.first;
                  enrolledPhotoUrl = base64Photo;
                  enrolledImageBytes = compressedJpg;
                  faceStatusMessage =
                      '✓ Enrolled ${pruned.length} SFace biometric templates';
                  isProcessingFace = false;
                });
                return;
              }

              // Native Android / iOS: Full ML Kit face detection + TFLite biometric extraction
              final enrollmentHelper = ref.read(faceEnrollmentHelperProvider);
              final result = await enrollmentHelper.processEnrollmentPhoto(
                photoFile!.path,
              );

              final compressedBytes = await ImageUtils.compressImageFile(
                photoFile,
              );
              final base64Photo = compressedBytes != null
                  ? ImageUtils.bytesToBase64(compressedBytes)
                  : null;

              setDialogState(() {
                enrolledEmbedding = result.faceEmbedding;
                enrolledPhotoUrl = base64Photo;
                enrolledImageBytes = compressedBytes ?? rawBytes!;
                enrolledImageFile = photoFile;
                faceStatusMessage = '✓ Face verified & biometrics enrolled';
                isProcessingFace = false;
              });
            } catch (e) {
              setDialogState(() {
                faceStatusMessage = e.toString().replaceAll('Exception: ', '');
                isProcessingFace = false;
              });
            }
          }

          InputDecoration buildFieldDecoration({
            required String hint,
            required Widget prefixIcon,
          }) {
            return InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: prefixIcon,
              filled: true,
              fillColor: fieldBgColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: defaultBorderColor, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: defaultBorderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.5,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withAlpha(isDark ? 80 : 30),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
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
                      // Header Row
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing
                                  ? Icons.edit_rounded
                                  : Icons.person_add_rounded,
                              color: AppColors.primary,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEditing
                                  ? 'Edit Member Details'
                                  : 'Add New Member',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            splashRadius: 18,
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      if (submitError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(isDark ? 40 : 18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withAlpha(120),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  submitError!,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFFCA5A5)
                                        : AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Face Photo & Biometric Enrollment Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: defaultBorderColor),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar Preview
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primaryLight.withAlpha(30),
                                    border: Border.all(
                                      color:
                                          (enrolledEmbedding != null ||
                                              enrolledPhotoUrl != null ||
                                              enrolledImageBytes != null)
                                          ? AppColors.success
                                          : defaultBorderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: () {
                                      if (enrolledImageBytes != null) {
                                        return Image.memory(
                                          enrolledImageBytes!,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      if (enrolledImageFile != null) {
                                        return Image.file(
                                          enrolledImageFile!,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      final photo = enrolledPhotoUrl;
                                      if (photo != null && photo.isNotEmpty) {
                                        if (photo.startsWith('http')) {
                                          return Image.network(
                                            ImageUtils.cacheBustedUrl(
                                              photo,
                                              version:
                                                  existingMember?.updatedAt,
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => const Icon(
                                                  Icons
                                                      .face_retouching_natural_rounded,
                                                  color: AppColors.primary,
                                                  size: 26,
                                                ),
                                          );
                                        }
                                        final bytes = ImageUtils.base64ToBytes(
                                          photo,
                                        );
                                        if (bytes != null) {
                                          return Image.memory(
                                            bytes,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => const Icon(
                                                  Icons
                                                      .face_retouching_natural_rounded,
                                                  color: AppColors.primary,
                                                  size: 26,
                                                ),
                                          );
                                        }
                                      }
                                      return const Icon(
                                        Icons.camera_front_rounded,
                                        color: Color(0xFF64748B),
                                        size: 26,
                                      );
                                    }(),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Action Buttons
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Member Face Photo (Optional)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Optional — used only if you enroll face recognition later',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: isProcessingFace
                                                ? null
                                                : () => pickFacePhoto(
                                                    ImageSource.camera,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.camera_alt_outlined,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Take Photo',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: isProcessingFace
                                                ? null
                                                : () => pickFacePhoto(
                                                    ImageSource.gallery,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF334155)
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .photo_library_outlined,
                                                    size: 14,
                                                    color: labelColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Gallery',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: labelColor,
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
                              ],
                            ),

                            // Status / Feedback message
                            if (isProcessingFace) ...[
                              const SizedBox(height: 10),
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Analyzing face biometrics...',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (faceStatusMessage != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: faceStatusMessage!.startsWith('✓')
                                      ? AppColors.successLight
                                      : AppColors.errorLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  faceStatusMessage!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: faceStatusMessage!.startsWith('✓')
                                        ? AppColors.successDark
                                        : AppColors.errorDark,
                                  ),
                                ),
                              ),
                            ] else if (enrolledEmbedding != null ||
                                enrolledPhotoUrl != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: AppColors.successDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      enrolledEmbedding != null
                                          ? 'Face Biometrics Enrolled (192 features)'
                                          : 'Member Photo Attached',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.successDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Name Field (required)
                      Text.rich(
                        TextSpan(
                          text: 'Name',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                          children: const [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: AppColors.primary,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: buildFieldDecoration(
                          hint: 'Enter full name',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                        autofocus: false,
                        validator: (val) {
                          final trimmed = val?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Please enter member name';
                          }
                          if (trimmed.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Number Field (required)
                      Text.rich(
                        TextSpan(
                          text: 'Phone Number',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                          children: const [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: phoneController,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: AppColors.primary,
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. +91 9876543210',
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                        validator: (val) {
                          final trimmed = val?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Please enter phone number';
                          }
                          final cleaned = trimmed.replaceAll(
                            RegExp(r'[\s\-\(\)\+]'),
                            '',
                          );
                          final digits =
                              (cleaned.startsWith('91') && cleaned.length == 12)
                              ? cleaned.substring(2)
                              : (cleaned.startsWith('0') && cleaned.length == 11
                                    ? cleaned.substring(1)
                                    : cleaned);

                          if (digits.length != 10) {
                            return 'Phone number must be exactly 10 digits';
                          }
                          if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                            return 'Please enter a valid 10-digit Indian mobile number (starts with 6–9)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Field (optional)
                      Text(
                        'Email (Optional)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: emailController,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: AppColors.primary,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: buildFieldDecoration(
                          hint: 'e.g. omkar@example.com',
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                        validator: (val) {
                          final trimmed = val?.trim() ?? '';
                          if (trimmed.isEmpty) return null;
                          final emailPattern = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailPattern.hasMatch(trimmed)) {
                            return 'Please enter a valid email address (e.g. name@gmail.com)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons (EXACTLY Equal Width and Height)
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF334155),
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) {
                                          return;
                                        }
                                        setDialogState(() {
                                          isSubmitting = true;
                                          submitError = null;
                                        });
                                        final name = nameController.text.trim();
                                        final phone = phoneController.text
                                            .trim();
                                        final email = emailController.text
                                            .trim();
                                        try {
                                          final activeScope = ref.read(
                                            activeAdminScopeProvider,
                                          );
                                          final isSuperAdmin = ref.read(
                                            isSuperAdminProvider,
                                          );
                                          final currentAdmin = ref.read(
                                            currentAdminUserProvider,
                                          );
                                          final targetAdminId =
                                              activeScope?.id ??
                                              (isSuperAdmin
                                                  ? null
                                                  : currentAdmin?.id);

                                          final repo = ref.read(
                                            employeeRepositoryProvider,
                                          );
                                          final bool hasFaceBiometrics =
                                              (enrolledPhotoUrl != null &&
                                                  enrolledPhotoUrl!
                                                      .isNotEmpty) ||
                                              (enrolledTemplates != null &&
                                                  enrolledTemplates!
                                                      .isNotEmpty) ||
                                              (enrolledEmbedding != null &&
                                                  enrolledEmbedding!
                                                      .isNotEmpty);
                                          if (isEditing) {
                                            await repo.updateEmployee(
                                              existingMember.id,
                                              name,
                                              phone: phone,
                                              email: email,
                                              role: selectedRole,
                                              isActive: isActive,
                                              adminId:
                                                  existingMember.adminId ??
                                                  targetAdminId,
                                              photoUrl: enrolledPhotoUrl,
                                              faceEmbedding: enrolledEmbedding,
                                              faceTemplates: enrolledTemplates,
                                              faceEnrolled: hasFaceBiometrics,
                                              faceModel:
                                                  enrolledTemplates != null &&
                                                      enrolledTemplates!
                                                          .isNotEmpty
                                                  ? FaceMatchingConfig.modelName
                                                  : null,
                                              faceModelVersion:
                                                  enrolledTemplates != null &&
                                                      enrolledTemplates!
                                                          .isNotEmpty
                                                  ? FaceMatchingConfig
                                                        .modelVersion
                                                  : null,
                                            );
                                            _invalidateMemberStreams();
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Updated "$name" successfully',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.success,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          } else {
                                            await repo.addEmployee(
                                              name,
                                              phone: phone,
                                              email: email,
                                              role: selectedRole,
                                              isActive: isActive,
                                              adminId: targetAdminId,
                                              photoUrl: enrolledPhotoUrl,
                                              faceEmbedding: enrolledEmbedding,
                                              faceTemplates: enrolledTemplates,
                                              faceEnrolled: hasFaceBiometrics,
                                              faceModel:
                                                  enrolledTemplates != null &&
                                                      enrolledTemplates!
                                                          .isNotEmpty
                                                  ? FaceMatchingConfig.modelName
                                                  : null,
                                              faceModelVersion:
                                                  enrolledTemplates != null &&
                                                      enrolledTemplates!
                                                          .isNotEmpty
                                                  ? FaceMatchingConfig
                                                        .modelVersion
                                                  : null,
                                            );
                                            _invalidateMemberStreams();
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx);
                                            }
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Added "$name" successfully',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.success,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          // Keep error inside the dialog — parent
                                          // SnackBars render behind the modal barrier.
                                          final message =
                                              ErrorHandler.getUserMessage(e);
                                          setDialogState(() {
                                            isSubmitting = false;
                                            submitError = message;
                                          });
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
                                    : Text(
                                        isEditing
                                            ? 'Save Changes'
                                            : 'Add Member',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
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

  int _getMemberVisitorCount(Employee member, Map<String, int> visitorCounts) {
    final byName = visitorCounts[member.name.trim().toLowerCase()] ?? 0;
    final byId = visitorCounts[member.id.toLowerCase()] ?? 0;
    final byPhone = visitorCounts[member.phone.trim().toLowerCase()] ?? 0;
    return max(byName, max(byId, byPhone));
  }

  List<Employee> _filterAndSort(
    List<Employee> rawList,
    Map<String, int> visitorCounts,
  ) {
    final list = rawList.where((u) {
      if (_statusFilter == MemberStatusFilter.active && !u.isActive) {
        return false;
      }
      if (_statusFilter == MemberStatusFilter.inactive && u.isActive) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(query) ||
          u.phone.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.role.toLowerCase().contains(query);
    }).toList();

    switch (_sortOption) {
      case MemberSortOption.mostVisitors:
        list.sort((a, b) {
          final countA = _getMemberVisitorCount(a, visitorCounts);
          final countB = _getMemberVisitorCount(b, visitorCounts);
          if (countB != countA) {
            return countB.compareTo(countA); // Highest visitors at top
          }
          // Tiebreaker 1: Date Added (earliest registered member first)
          final da = a.createdAt ?? DateTime(2099);
          final db = b.createdAt ?? DateTime(2099);
          final dateCmp = da.compareTo(db);
          if (dateCmp != 0) return dateCmp;

          // Tiebreaker 2: Alphabetical by Name (A-Z)
          final nameCmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (nameCmp != 0) return nameCmp;

          // Tiebreaker 3: ID
          return a.id.compareTo(b.id);
        });
      case MemberSortOption.nameAsc:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case MemberSortOption.nameDesc:
        list.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
      case MemberSortOption.newest:
        list.sort((a, b) {
          final da = a.createdAt ?? DateTime(2020);
          final db = b.createdAt ?? DateTime(2020);
          final dateCmp = db.compareTo(da);
          if (dateCmp != 0) return dateCmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return list;
  }

  Widget _buildKpiMetrics(
    BuildContext context,
    int totalMembers,
    int activeMembers,
    int totalVisitorsInvited,
    String avgVisitorsPerMember,
    bool isDark,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final isMobile = screenWidth < 768;

    final card1 = AppMetricCard(
      title: 'Total Members',
      value: '$totalMembers',
      subtitle: isMobile ? 'Registered' : 'Registered attendees',
      icon: Icons.people_alt_rounded,
      accentColor: AppColors.primary,
      isCompact: isMobile,
    );

    final card2 = AppMetricCard(
      title: 'Active Members',
      value: '$activeMembers',
      subtitle: isMobile ? 'Enabled' : 'Enabled for check-in',
      icon: Icons.check_circle_rounded,
      accentColor: const Color(0xFF10B981),
      isCompact: isMobile,
    );

    if (isDesktop || isMobile) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 10),
          Expanded(child: card2),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          SizedBox(width: 220, child: card1),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: card2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = context.isDesktop || context.isTablet;
    final employeesAsync = ref.watch(employeesStreamProvider);
    final visitorsAsync = ref.watch(allVisitorsProvider);

    final members = employeesAsync.value ?? [];
    final visitors = visitorsAsync.value ?? [];

    // Map visitor counts by member name (case-insensitive) & ID & phone
    final Map<String, int> visitorCounts = {};
    for (final v in visitors) {
      final inviter = (v.invitedByMember ?? '').trim();
      if (inviter.isNotEmpty) {
        final key = inviter.toLowerCase();
        visitorCounts[key] = (visitorCounts[key] ?? 0) + 1;
      }
    }

    final totalMembers = members.length;
    final activeMembersCount = members.where((m) => m.isActive).length;

    // Calculate total visitors invited by registered members
    int totalVisitorsInvited = 0;
    for (final m in members) {
      totalVisitorsInvited += _getMemberVisitorCount(m, visitorCounts);
    }
    final avgVisitorsPerMember = totalMembers > 0
        ? (totalVisitorsInvited / totalMembers).toStringAsFixed(1)
        : '0.0';

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    Widget buildMainContent(bool useExpanded) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDesktop)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Single Button for Mobile Action: Add Member
                    SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _showAddEditMemberDialog,
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text(
                          'Add Member',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          elevation: 1,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                AppPageHeader(
                  title: 'Member Management',
                  isCompact: false,
                  actions: [
                    FilledButton.icon(
                      onPressed: _showAddEditMemberDialog,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add Member'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.smAll,
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // KPI Metrics Cards Banner
              _buildKpiMetrics(
                context,
                totalMembers,
                activeMembersCount,
                totalVisitorsInvited,
                avgVisitorsPerMember,
                isDark,
              ),

              const SizedBox(height: 16),

              if (useExpanded)
                Expanded(
                  child: _buildTableCard(
                    context,
                    employeesAsync,
                    visitorCounts,
                    isDesktop,
                    useExpanded: true,
                  ),
                )
              else
                _buildTableCard(
                  context,
                  employeesAsync,
                  visitorCounts,
                  isDesktop,
                  useExpanded: false,
                ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.fromLTRB(hPadding, 20, hPadding, 20),
        child: buildMainContent(true),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPadding, 16, hPadding, 80),
      child: buildMainContent(false),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    AsyncValue<List<Employee>> employeesAsync,
    Map<String, int> visitorCounts,
    bool isDesktop, {
    required bool useExpanded,
  }) {
    return employeesAsync.when(
      loading: () => const AppCard(
        elevation: 1,
        padding: EdgeInsets.all(20),
        child: CheckInCardSkeletonList(count: 4),
      ),
      error: (err, _) => AppCard(
        elevation: 1,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Error loading members: $err',
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.refresh(employeesStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (membersList) {
        if (membersList.isEmpty) {
          return _buildEmptyState(context);
        }

        final filtered = _filterAndSort(membersList, visitorCounts);

        return AppCard(
          elevation: 2,
          padding: EdgeInsets.zero,
          borderRadius: AppRadius.mdAll,
          shadows: AppShadows.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTableToolbar(
                context,
                membersList.length,
                filtered.length,
                isDesktop,
              ),

              const Divider(height: 1),

              if (filtered.isEmpty)
                _buildNoSearchResults(context)
              else if (isDesktop)
                if (useExpanded)
                  Expanded(
                    child: _buildDesktopTable(context, filtered, visitorCounts),
                  )
                else
                  _buildDesktopTable(context, filtered, visitorCounts)
              else
                _buildMobileList(context, filtered, visitorCounts),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableToolbar(
    BuildContext context,
    int totalCount,
    int filteredCount,
    bool isDesktop,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(6) : Colors.grey.withAlpha(12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by member name or phone...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdAll,
                        borderSide: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(18),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Text(
                    'Showing $filteredCount of $totalCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppFilterDropdown<MemberStatusFilter>(
                      value: _statusFilter,
                      labelPrefix: 'Status',
                      items: MemberStatusFilter.values.map((filter) {
                        return DropdownMenuItem(
                          value: filter,
                          child: Text(filter.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _statusFilter = val);
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    AppFilterDropdown<MemberSortOption>(
                      value: _sortOption,
                      labelPrefix: 'Sort',
                      items: MemberSortOption.values.map((opt) {
                        return DropdownMenuItem(
                          value: opt,
                          child: Text(opt.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _sortOption = val);
                        }
                      },
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search name or phone...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.surfaceDark
                        : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.outlineDark
                            : AppColors.outlineLight,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.outlineDark
                            : AppColors.outlineLight,
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
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppFilterDropdown<MemberStatusFilter>(
                        value: _statusFilter,
                        labelPrefix: 'Status',
                        isExpanded: true,
                        isCompact: true,
                        items: MemberStatusFilter.values.map((filter) {
                          return DropdownMenuItem(
                            value: filter,
                            child: Text(filter.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _statusFilter = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppFilterDropdown<MemberSortOption>(
                        value: _sortOption,
                        labelPrefix: 'Sort',
                        isExpanded: true,
                        isCompact: true,
                        items: MemberSortOption.values.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(opt.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _sortOption = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<Employee> members,
    Map<String, int> visitorCounts,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: Colors.grey,
    );

    // Rank icon / pill styling
    Widget buildRankWidget(int index, Employee member, int visitorCount) {
      if (_sortOption == MemberSortOption.mostVisitors && visitorCount > 0) {
        if (index == 1) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: AppRadius.fullAll,
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🥇', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 2),
                  Text(
                    '1',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (index == 2) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: AppRadius.fullAll,
                border: Border.all(color: const Color(0xFF94A3B8)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🥈', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 2),
                  Text(
                    '2',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (index == 3) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: AppRadius.fullAll,
                border: Border.all(color: const Color(0xFFFB923C)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🥉', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 2),
                  Text(
                    '3',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC2410C),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      return Text(
        '$index',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Widget buildTableHeader() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceVariantDark.withAlpha(120)
              : AppColors.surfaceVariantLight.withAlpha(160),
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withAlpha(40)),
          ),
        ),
        child: const Row(
          children: [
            SizedBox(width: 75, child: Text('RANK', style: headerStyle)),
            Expanded(flex: 1, child: Text('MEMBER NAME', style: headerStyle)),
            Expanded(flex: 1, child: Text('PHONE NUMBER', style: headerStyle)),
            Expanded(flex: 1, child: Text('VISITORS', style: headerStyle)),
            Expanded(
              flex: 1,
              child: Text('ACCOUNT STATUS', style: headerStyle),
            ),
            Expanded(flex: 1, child: Text('STATUS', style: headerStyle)),
            Expanded(flex: 1, child: Text('DATE', style: headerStyle)),
            SizedBox(
              width: 70,
              child: Text(
                'ACTIONS',
                style: headerStyle,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildDataRow(int index, Employee member) {
      final rankIndex = index + 1;
      final avatarColor = _getAvatarColor(member.name);
      final initials = _getInitials(member.name);
      final isZebra = index.isOdd;
      final visitorCount = _getMemberVisitorCount(member, visitorCounts);

      return Container(
        decoration: BoxDecoration(
          color: isZebra
              ? (isDark ? Colors.white.withAlpha(4) : Colors.black.withAlpha(3))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withAlpha(40)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // RANK (75px)
            SizedBox(
              width: 75,
              child: Align(
                alignment: Alignment.centerLeft,
                child: buildRankWidget(rankIndex, member, visitorCount),
              ),
            ),

            // MEMBER NAME (flex: 1,)
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  _buildMemberAvatar(
                    member: member,
                    size: 34,
                    avatarColor: avatarColor,
                    initials: initials,
                    fontSize: 12,
                    borderRadius: AppRadius.xsAll,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // PHONE NUMBER (flex: 1,)
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  member.phone.isNotEmpty ? member.phone : '—',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: member.phone.isNotEmpty
                        ? (isDark ? Colors.white70 : const Color(0xFF334155))
                        : Colors.grey,
                  ),
                ),
              ),
            ),

            // VISITORS (flex: 1,)
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: visitorCount > 0
                        ? 'Filter Visitors Overview by ${member.name}'
                        : 'No invited visitors yet',
                    child: InkWell(
                      onTap: visitorCount > 0
                          ? () {
                              ref
                                  .read(visitorFilterProvider.notifier)
                                  .setSearchQuery(member.name);
                              context.go('/admin-visitors');
                            }
                          : null,
                      borderRadius: AppRadius.fullAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: visitorCount > 0
                              ? const Color(0xFF0284C7).withAlpha(18)
                              : (isDark
                                    ? Colors.white.withAlpha(8)
                                    : Colors.grey.withAlpha(15)),
                          borderRadius: AppRadius.fullAll,
                          border: Border.all(
                            color: visitorCount > 0
                                ? const Color(0xFF0284C7).withAlpha(55)
                                : (isDark
                                      ? Colors.white.withAlpha(15)
                                      : Colors.grey.withAlpha(30)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_pin_circle_rounded,
                              size: 13,
                              color: visitorCount > 0
                                  ? const Color(0xFF0284C7)
                                  : (isDark ? Colors.white38 : Colors.grey),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$visitorCount ${visitorCount == 1 ? "Visitor" : "Visitors"}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: visitorCount > 0
                                    ? const Color(0xFF0284C7)
                                    : (isDark
                                          ? Colors.white60
                                          : Colors.grey[700]),
                              ),
                            ),
                            if (visitorCount > 0) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 9,
                                color: Color(0xFF0284C7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // STATUS (flex: 1,)
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (member.isActive ? AppColors.success : Colors.grey)
                        .withAlpha(18),
                    borderRadius: AppRadius.fullAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: member.isActive
                              ? AppColors.success
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        member.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: member.isActive
                              ? AppColors.success
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // STATUS (flex: 1,)
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                  message: member.isActive
                      ? 'Deactivate ${member.name}'
                      : 'Activate ${member.name}',
                  child: SizedBox(
                    height: 22,
                    width: 38,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Switch.adaptive(
                        value: member.isActive,
                        activeThumbColor: AppColors.success,
                        activeTrackColor: AppColors.success.withAlpha(140),
                        inactiveThumbColor: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        inactiveTrackColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (bool _) => _toggleMemberStatus(member),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // DATE (flex: 1,)
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(member.createdAt),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  if (member.createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(member.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(
                          180,
                        ),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ACTIONS (70px)
            SizedBox(
              width: 70,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Edit Member Details',
                  onPressed: () =>
                      _showAddEditMemberDialog(existingMember: member),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > 1120
            ? constraints.maxWidth
            : 1120.0;
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: tableWidth,
            height: hasBoundedHeight ? constraints.maxHeight : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fixed Table Header (Does not scroll vertically)
                buildTableHeader(),

                // Scrollable Table Rows (Only data rows scroll)
                if (hasBoundedHeight)
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemBuilder: (context, index) =>
                          buildDataRow(index, members[index]),
                    ),
                  )
                else
                  ...members.asMap().entries.map(
                    (entry) => buildDataRow(entry.key, entry.value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileList(
    BuildContext context,
    List<Employee> members,
    Map<String, int> visitorCounts,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = members[index];
        final avatarColor = _getAvatarColor(member.name);
        final initials = _getInitials(member.name);
        final rank = index + 1;
        final visitorCount = _getMemberVisitorCount(member, visitorCounts);

        return AppCard(
          padding: const EdgeInsets.all(12),
          borderRadius: AppRadius.mdAll,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Avatar with subtle corner rank badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildMemberAvatar(
                    member: member,
                    size: 40,
                    avatarColor: avatarColor,
                    initials: initials,
                    fontSize: 13.5,
                    borderRadius: AppRadius.smAll,
                  ),
                  if (_sortOption == MemberSortOption.mostVisitors)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: rank == 1 && visitorCount > 0
                              ? const Color(0xFFF59E0B)
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFF64748B)),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: AppShadows.sm,
                        ),
                        child: Text(
                          '#$rank',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // 2. Member Name, Unified Chips, Phone & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Visitor Count Pill
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: visitorCount > 0
                                ? () {
                                    ref
                                        .read(visitorFilterProvider.notifier)
                                        .setSearchQuery(member.name);
                                    context.go('/admin-visitors');
                                  }
                                : null,
                            borderRadius: AppRadius.fullAll,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withAlpha(18),
                                borderRadius: AppRadius.fullAll,
                                border: Border.all(
                                  color: const Color(0xFF0284C7).withAlpha(40),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '👥 $visitorCount ${visitorCount == 1 ? "Visitor" : "Visitors"}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  if (visitorCount > 0) ...[
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 8,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Status Pill & Quick Toggle
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (member.isActive
                                            ? AppColors.success
                                            : Colors.grey)
                                        .withAlpha(18),
                                borderRadius: AppRadius.fullAll,
                                border: Border.all(
                                  color:
                                      (member.isActive
                                              ? AppColors.success
                                              : Colors.grey)
                                          .withAlpha(40),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                member.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: member.isActive
                                      ? AppColors.success
                                      : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              height: 18,
                              width: 32,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: Switch.adaptive(
                                  value: member.isActive,
                                  activeThumbColor: AppColors.success,
                                  activeTrackColor: AppColors.success.withAlpha(
                                    140,
                                  ),
                                  inactiveThumbColor: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  inactiveTrackColor: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFCBD5E1),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (bool _) =>
                                      _toggleMemberStatus(member),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${member.phone.isNotEmpty ? member.phone : "No Phone"}${member.createdAt != null ? " • ${_formatDate(member.createdAt)}" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Edit Action with 44x44 Accessible Tap Target
              SizedBox(
                width: 44,
                height: 44,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () =>
                        _showAddEditMemberDialog(existingMember: member),
                    borderRadius: BorderRadius.circular(22),
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.outlineDark
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoSearchResults(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 48,
              color: Colors.grey.withAlpha(120),
            ),
            const SizedBox(height: 12),
            Text(
              'No members matching "$_searchQuery"',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear Search'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMemberStatus(Employee member) async {
    final newStatus = !member.isActive;
    try {
      await ref
          .read(employeeRepositoryProvider)
          .toggleEmployeeStatus(member.id, newStatus);
      _invalidateMemberStreams();
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.name} is now ${newStatus ? "Active" : "Inactive"}',
            ),
            backgroundColor: newStatus
                ? AppColors.success
                : const Color(0xFF64748B),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      elevation: 2,
      padding: const EdgeInsets.all(40),
      borderRadius: AppRadius.mdAll,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Members Found in Database',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add registered member names to populate the QR check-in selection menu.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showAddEditMemberDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('+ Add First Member'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
