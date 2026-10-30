import 'package:flutter/material.dart';

/// Branded MetaPhi loading indicator widget.
///
/// Features:
/// - Displays the official MetaPhi "Your Vision, Our Algorithm" logo.
/// - High-contrast, theme-adaptive loading card.
/// - Circular progress spinner in MetaPhi brand blue.
/// - Informative status message.
class MetaPhiLoadingIndicator extends StatelessWidget {
  const MetaPhiLoadingIndicator({
    super.key,
    this.message,
    this.logoWidth,
    this.showCard = false,
  });

  /// Deprecated/ignored message parameter so caller sites with named arg do not break.
  final String? message;

  /// Custom width for the MetaPhi tagline logo image.
  final double? logoWidth;

  /// Whether to display the logo and spinner within an elevated card.
  final bool showCard;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 400;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // MetaPhi "Your Vision, Our Algorithm" Logo without background
        Image.asset(
          'assets/images/metaphi_tagline_logo.webp',
          width: logoWidth ?? (isCompact ? 150 : 185),
          fit: BoxFit.contain,
        ),

        const SizedBox(height: 24),

        // Brand-tinted CircularProgressIndicator
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3.2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
          ),
        ),
      ],
    );

    final displayContent = FittedBox(fit: BoxFit.scaleDown, child: content);

    if (!showCard) {
      return displayContent;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20 : 32,
        vertical: isCompact ? 22 : 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 70 : 14),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: displayContent,
    );
  }
}

/// Pass-through route wrapper kept for call-site compatibility.
///
/// Previously enforced a 1–2s branded spinner before showing [child], which
/// made every login/QR navigation feel lagged. Content paints immediately now.
class PageLoadingTransitionWrapper extends StatelessWidget {
  const PageLoadingTransitionWrapper({
    super.key,
    required this.child,
    this.message,
    this.minimumDuration,
  });

  final Widget child;

  /// Ignored — kept so existing named arguments still compile.
  final String? message;

  /// Ignored — kept so existing named arguments still compile.
  final Duration? minimumDuration;

  @override
  Widget build(BuildContext context) => child;
}
