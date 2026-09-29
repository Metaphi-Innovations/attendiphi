import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/member_photo.dart';
import '../../../employee/domain/entities/employee.dart';

/// Card displayed when a member's face has been successfully recognized.
/// Shows avatar, name, phone, verified badge, and a re-scan option.
class RecognizedMemberCard extends StatelessWidget {
  const RecognizedMemberCard({
    super.key,
    required this.member,
    required this.confidence,
    required this.onRescan,
    this.capturedPhotoBytes,
  });

  final Employee member;
  final double confidence;
  final VoidCallback onRescan;
  final Uint8List? capturedPhotoBytes;

  @override
  Widget build(BuildContext context) {
    final initials = member.name.isNotEmpty
        ? member.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'M';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withAlpha(25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verified Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withAlpha(80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.successDark,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Face Verified',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successDark,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
                tooltip: 'Scan Again',
                onPressed: onRescan,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Member Profile Row
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  border: Border.all(color: AppColors.primaryLight, width: 2),
                ),
                child: () {
                  Widget buildFallback() => Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      );

                  if (capturedPhotoBytes != null && capturedPhotoBytes!.isNotEmpty) {
                    return ClipOval(
                      child: Image.memory(
                        capturedPhotoBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => buildFallback(),
                      ),
                    );
                  }

                  final photo = member.photoUrl;
                  if (photo != null && photo.trim().isNotEmpty) {
                    return ClipOval(
                      child: MemberPhoto(
                        member: member,
                        width: 64,
                        height: 64,
                        errorBuilder: (_, _, _) => buildFallback(),
                      ),
                    );
                  }
                  return buildFallback();
                }(),
              ),
              const SizedBox(width: 16),

              // Member Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Builder(
                          builder: (context) {
                            final normalized = Validators.normalizePhone(member.phone);
                            final displayPhone = normalized.isNotEmpty
                                ? '+91 $normalized'
                                : (member.phone.isNotEmpty ? member.phone : 'No phone');
                            return Text(
                              displayPhone,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    if (member.role.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          member.role,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ready to Check In notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Biometric face matched. Click Check-In below to log attendance.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
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
}
