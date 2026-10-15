import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/checkin/domain/entities/check_in_submission.dart';
import '../../features/checkin/presentation/providers/checkin_providers.dart';
import 'stable_base64_image.dart';

/// On-demand check-in selfie (Storage signed URL or legacy base64).
class CheckInPhotoImage extends ConsumerWidget {
  const CheckInPhotoImage({
    super.key,
    required this.submission,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
  });

  final CheckInSubmission submission;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inline = submission.photoBase64?.trim() ?? '';
    if (inline.isNotEmpty) {
      final img = StableBase64Image(
        base64: inline,
        width: width,
        height: height,
        fit: fit,
      );
      if (borderRadius == null) return img;
      return ClipRRect(borderRadius: borderRadius!, child: img);
    }

    final hasPhoto =
        submission.hasPhoto ||
        (submission.photoPath?.trim().isNotEmpty ?? false);
    if (!hasPhoto) {
      return placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: const ColoredBox(color: Color(0xFFE2E8F0)),
          );
    }

    final asyncUrl = ref.watch(checkInPhotoUrlProvider(submission));
    return asyncUrl.when(
      loading: () =>
          placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error: (_, _) =>
          placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: const Icon(Icons.person),
          ),
      data: (url) {
        if (url == null || url.isEmpty) {
          return placeholder ??
              SizedBox(
                width: width,
                height: height,
                child: const Icon(Icons.person_outline),
              );
        }
        if (url.startsWith('data:image')) {
          final comma = url.indexOf(',');
          final b64 = comma >= 0 ? url.substring(comma + 1) : url;
          final img = StableBase64Image(
            base64: b64,
            width: width,
            height: height,
            fit: fit,
          );
          if (borderRadius == null) return img;
          return ClipRRect(borderRadius: borderRadius!, child: img);
        }
        final image = Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) =>
              placeholder ?? const Icon(Icons.broken_image_outlined),
        );
        if (borderRadius == null) return image;
        return ClipRRect(borderRadius: borderRadius!, child: image);
      },
    );
  }
}

/// Resolves a displayable photo URL for a lean check-in row.
final checkInPhotoUrlProvider = FutureProvider.autoDispose
    .family<String?, CheckInSubmission>((ref, submission) {
      final repo = ref.watch(checkInRepositoryProvider);
      return repo.resolveCheckInPhotoUrl(submission);
    });
