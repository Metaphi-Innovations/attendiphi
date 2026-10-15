import 'package:flutter/material.dart';

import '../utils/image_utils.dart';

/// Decodes base64 once per source string and keeps the previous frame while
/// parents rebuild (e.g. live check-in polling). Prevents avatar flash.
class StableBase64Image extends StatefulWidget {
  const StableBase64Image({
    super.key,
    required this.base64,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.clipOval = false,
  });

  final String? base64;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool clipOval;

  @override
  State<StableBase64Image> createState() => _StableBase64ImageState();
}

class _StableBase64ImageState extends State<StableBase64Image> {
  MemoryImage? _provider;

  @override
  void initState() {
    super.initState();
    _syncBytes(widget.base64);
  }

  @override
  void didUpdateWidget(covariant StableBase64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64 != widget.base64) {
      _syncBytes(widget.base64);
    }
  }

  void _syncBytes(String? base64) {
    final decoded = ImageUtils.base64ToBytes(base64);
    _provider = (decoded != null && decoded.isNotEmpty)
        ? MemoryImage(decoded)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return SizedBox(width: widget.width, height: widget.height);
    }

    final image = Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );

    if (widget.clipOval) {
      return ClipOval(child: image);
    }
    final radius = widget.borderRadius;
    if (radius != null) {
      return ClipRRect(borderRadius: radius, child: image);
    }
    return image;
  }
}
