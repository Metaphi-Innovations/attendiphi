import 'package:flutter/material.dart';

import '../../features/employee/domain/entities/employee.dart';
import '../utils/image_utils.dart';
import 'stable_base64_image.dart';

/// Renders a member's current profile photo from [Employee.photoUrl].
///
/// HTTP photos are cache-busted with [Employee.updatedAt] (stable when null).
/// Base64 photos use [StableBase64Image] so live roster rebuilds do not flash.
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
    if (photo.isEmpty) {
      return errorBuilder?.call(context, 'missing-photo', StackTrace.empty) ??
          const SizedBox.shrink();
    }

    if (photo.startsWith('http://') || photo.startsWith('https://')) {
      final version = member.updatedAt;
      return Image.network(
        ImageUtils.cacheBustedUrl(photo, version: version),
        key: ValueKey(
          '${member.id}_${version?.millisecondsSinceEpoch ?? 0}',
        ),
        width: width,
        height: height,
        fit: fit,
        // Keep the previous frame while LIVE SYNC rebuilds the roster.
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: errorBuilder,
      );
    }

    if (ImageUtils.base64ToBytes(photo) == null) {
      return errorBuilder?.call(context, 'invalid-photo', StackTrace.empty) ??
          const SizedBox.shrink();
    }

    return StableBase64Image(
      key: ValueKey(member.id),
      base64: photo,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
