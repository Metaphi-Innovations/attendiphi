import 'package:flutter/material.dart';

import '../../features/employee/domain/entities/employee.dart';
import '../utils/image_utils.dart';

/// Renders a member's current profile photo from [Employee.photoUrl].
///
/// HTTP photos are cache-busted with [Employee.updatedAt]. Base64 photos
/// are keyed by member id + updatedAt so Flutter does not reuse a stale
/// [MemoryImage] after an admin update.
class MemberPhoto extends StatelessWidget {
  const MemberPhoto({
    super.key,
    required this.member,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final Employee member;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final photo = member.photoUrl?.trim() ?? '';
    final version = member.updatedAt;
    final imageKey = ValueKey(
      '${member.id}_${version?.millisecondsSinceEpoch ?? 0}_${photo.length}',
    );

    if (photo.isEmpty) {
      return errorBuilder?.call(context, 'missing-photo', StackTrace.empty) ??
          const SizedBox.shrink();
    }

    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return Image.network(
        ImageUtils.cacheBustedUrl(photo, version: version),
        key: imageKey,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: false,
        errorBuilder: errorBuilder,
      );
    }

    final bytes = ImageUtils.base64ToBytes(photo);
    if (bytes == null) {
      return errorBuilder?.call(context, 'invalid-photo', StackTrace.empty) ??
          const SizedBox.shrink();
    }
    return Image.memory(
      bytes,
      key: imageKey,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: false,
      errorBuilder: errorBuilder,
    );
  }
}
