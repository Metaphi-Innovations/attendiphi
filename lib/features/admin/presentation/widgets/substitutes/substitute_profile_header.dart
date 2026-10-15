import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/widgets/check_in_photo_image.dart';
import '../../../../checkin/domain/entities/check_in_submission.dart';
import '../../../../checkin/domain/entities/check_in_type.dart';
import '../../../domain/substitutes_analytics.dart';

/// Substitute identity: photo, name, phone only.
class SubstituteProfileHeader extends StatelessWidget {
  const SubstituteProfileHeader({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final SubstituteProfile profile;
  final bool compact;

  /// Display-only phone formatting — `XXXXX XXXXX` when valid (no +91).
  static String formatPhoneDisplay(String raw) =>
      formatSubstitutePhoneDisplay(raw);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final phoneShown = formatPhoneDisplay(profile.phoneDisplay);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderAvatar(
          visit: profile.latestVisitWithPhoto,
          name: profile.displayName,
          identityKey: profile.identityKey,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: TextStyle(
                  fontSize: compact ? 20 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.35,
                  height: 1.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                phoneShown.isEmpty ? 'No phone on file' : phoneShown,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.visit,
    required this.name,
    required this.identityKey,
  });

  final SubstituteVisitRecord? visit;
  final String name;
  final String identityKey;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 26,
          color: AppColors.primary,
        ),
      ),
    );
    final v = visit;
    if (v == null) return placeholder;
    return CheckInPhotoImage(
      key: ValueKey('sub-header-$identityKey'),
      submission: CheckInSubmission(
        id: v.checkInId,
        locationId: '',
        locationName: v.locationName ?? '',
        userName: v.substituteDisplayName,
        userPhone: v.substitutePhoneDisplay,
        type: CheckInType.substitute,
        userLatitude: 0,
        userLongitude: 0,
        gpsAccuracy: 0,
        distanceMeters: 0,
        timestamp: v.attendedAt,
        photoBase64: v.photoBase64,
        photoPath: v.photoPath,
        hasPhoto: v.hasPhoto,
      ),
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(16),
      placeholder: placeholder,
    );
  }
}
