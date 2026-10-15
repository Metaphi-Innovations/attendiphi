import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

class SubstitutePhotoCard extends StatelessWidget {
  const SubstitutePhotoCard({
    super.key,
    required this.photoBase64,
    required this.onTakePhoto,
  });

  final String? photoBase64;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final imageBytes = ImageUtils.base64ToBytes(photoBase64);

    return AppCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      text: 'Face Verification Photo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (imageBytes != null)
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Change'),
                  onPressed: onTakePhoto,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageBytes != null)
            Center(
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: Image.memory(
                  imageBytes,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Center(
              child: Column(
                children: [
                  const Text(
                    'Substitutes must provide a live face photo for attendance verification.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  AppButton.primary(
                    label: 'Take Face Photo',
                    icon: Icons.camera_alt_rounded,
                    fullWidth: false,
                    onPressed: onTakePhoto,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
