import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';

/// Card displayed when a captured face does not match any registered member.
/// Provides a clear explanation, photo preview, and seamless options to
/// either retake the photo or immediately switch to Visitor check-in.
class UnrecognizedMemberCard extends StatelessWidget {
  const UnrecognizedMemberCard({
    super.key,
    this.capturedPhotoBytes,
    required this.onRetake,
  });

  final Uint8List? capturedPhotoBytes;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFDA4AF), // Rose border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withAlpha(15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Status Badge & Retake Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2), // Rose background
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_off_rounded,
                      color: Color(0xFFE11D48),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'No Member Detected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 20, color: Color(0xFF64748B)),
                tooltip: 'Retake Photo',
                onPressed: onRetake,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Photo Preview & Notice Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Captured Selfie Thumbnail or Fallback Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(
                    color: const Color(0xFFF43F5E),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: capturedPhotoBytes != null
                      ? Image.memory(
                          capturedPhotoBytes!,
                          fit: BoxFit.cover,
                          width: 68,
                          height: 68,
                        )
                      : const Center(
                          child: Icon(
                            Icons.no_accounts_rounded,
                            size: 32,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Description
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Face Not Recognized',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Your face does not match any registered member in this chapter.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Retake Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text(
                'Retake Selfie',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
