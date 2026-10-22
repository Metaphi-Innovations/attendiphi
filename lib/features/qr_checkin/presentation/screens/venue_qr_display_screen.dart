import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/router/app_url.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../location/domain/entities/location_config.dart';
import '../../domain/check_in_session_token.dart';

/// Screen displaying check-in QR standees from September 2026 to September 2027.
///
/// Features:
/// - Filtered strictly by 1 month at a time (September 2026 – September 2027).
/// - Date restriction ON: Thursdays only. OFF: every day of the month.
/// - Generates a distinct, unique QR payload for each session date.
/// - Full interactive Standee preview with "View QR" and "Download QR" options.
/// - Bulk "Download All This Month" capability.
class VenueQrDisplayScreen extends ConsumerStatefulWidget {
  const VenueQrDisplayScreen({
    super.key,
    this.location = const LocationConfig(
      id: 'location_x',
      name: 'Jade Luxury Banquets, Mumbai',
      latitude: 18.9888622,
      longitude: 72.8152475,
      radiusMeters: 500.0,
      address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
    ),
    this.initialDate,
  });

  final LocationConfig location;
  final DateTime? initialDate;

  @override
  ConsumerState<VenueQrDisplayScreen> createState() =>
      _VenueQrDisplayScreenState();
}

class _VenueQrDisplayScreenState extends ConsumerState<VenueQrDisplayScreen> {
  final GlobalKey _standeeCardKey = GlobalKey();

  late final List<DateTime> _availableMonths;
  late DateTime _selectedMonth;
  late DateTime _selectedThursday;
  bool _isDownloading = false;

  DateTime get _now => widget.initialDate ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _availableMonths = _generateMonthRange();
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    // Select the current month if in available months range, otherwise default to first
    final matchingMonth = _availableMonths.firstWhere(
      (m) => m.year == today.year && m.month == today.month,
      orElse: () => _availableMonths.first,
    );
    _selectedMonth = matchingMonth;
    final thursdays = _getThursdaysForMonth(_selectedMonth);
    _selectedThursday = thursdays.firstWhere(
      (t) =>
          DateTime(t.year, t.month, t.day).isAtSameMomentAs(today) ||
          DateTime(t.year, t.month, t.day).isAfter(today),
      orElse: () =>
          thursdays.isNotEmpty ? thursdays.first : DateTime(2026, 9, 3),
    );
  }

  /// Generates the list of months from September 2026 to September 2027 (13 months total).
  List<DateTime> _generateMonthRange() {
    final months = <DateTime>[];
    for (int year = 2026; year <= 2027; year++) {
      final startMonth = (year == 2026) ? 9 : 1;
      final endMonth = (year == 2027) ? 9 : 12;
      for (int m = startMonth; m <= endMonth; m++) {
        months.add(DateTime(year, m, 1));
      }
    }
    return months;
  }

  /// Automatically determines if QR codes and downloads are active for the given month.
  /// Automatically unlocks once the date reaches that month (i.e. on or after the 1st of that month).
  bool _isMonthActive(DateTime month) {
    final now = _now;
    if (now.year > month.year) return true;
    if (now.year == month.year && now.month >= month.month) return true;
    return false;
  }

  /// Session dates for [month].
  ///
  /// Date restriction ON → Thursdays only. OFF → every calendar day.
  List<DateTime> _getThursdaysForMonth(
    DateTime month, {
    bool? dateRestricted,
  }) {
    final bool restrictDates =
        dateRestricted ?? ref.read(dateRestrictionEnabledProvider);
    final dates = <DateTime>[];
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      if (!restrictDates || date.weekday == DateTime.thursday) {
        dates.add(date);
      }
    }
    return dates;
  }

  /// Builds the unique QR check-in payload for a given Thursday.
  ///
  /// Public URL is opaque: `/checkin/<v1.…>` (no cleartext date/locationId).
  /// Returns null when signing is unavailable (e.g. release build missing
  /// `CHECKIN_SESSION_TOKEN_SECRET`) so the UI can show an error instead of
  /// blanking the whole page.
  String? _tryBuildQrPayload(DateTime thursdayDate) {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(thursdayDate);
      final token = CheckInSessionToken.create(
        locationId: widget.location.id,
        sessionDate: dateStr,
      );
      return AppUrl.checkInPublic(path: RouteNames.checkinFormPath(token));
    } on Object {
      return null;
    }
  }

  /// Builds the unique QR check-in payload for a given Thursday.
  ///
  /// Throws when signing is unavailable — prefer [_tryBuildQrPayload] in build.
  String _buildQrPayload(DateTime thursdayDate) {
    final payload = _tryBuildQrPayload(thursdayDate);
    if (payload == null) {
      throw StateError(
        'Unable to create check-in QR payload. Ensure the web release was '
        'built with CHECKIN_SESSION_TOKEN_SECRET '
        '(see scripts/build_web_release.sh).',
      );
    }
    return payload;
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
      final thursdays = _getThursdaysForMonth(newMonth);
      if (thursdays.isNotEmpty) {
        final now = _now;
        final today = DateTime(now.year, now.month, now.day);
        _selectedThursday = thursdays.firstWhere(
          (t) =>
              DateTime(t.year, t.month, t.day).isAtSameMomentAs(today) ||
              DateTime(t.year, t.month, t.day).isAfter(today),
          orElse: () => thursdays.first,
        );
      }
    });
  }

  void _selectPreviousMonth() {
    final currentIndex = _availableMonths.indexWhere(
      (m) => m.year == _selectedMonth.year && m.month == _selectedMonth.month,
    );
    if (currentIndex > 0) {
      _onMonthChanged(_availableMonths[currentIndex - 1]);
    }
  }

  void _selectNextMonth() {
    final currentIndex = _availableMonths.indexWhere(
      (m) => m.year == _selectedMonth.year && m.month == _selectedMonth.month,
    );
    if (currentIndex < _availableMonths.length - 1) {
      _onMonthChanged(_availableMonths[currentIndex + 1]);
    }
  }

  /// Downloads the Thursday QR Standee as a high-resolution PNG image.
  Future<void> _downloadThursdayPng(
    DateTime thursdayDate, {
    bool fullStandee = true,
  }) async {
    if (!_isMonthActive(thursdayDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'QR Standee for ${DateFormat('MMMM yyyy').format(thursdayDate)} will auto-unlock on 01 ${DateFormat('MMM yyyy').format(thursdayDate)}.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(thursdayDate);
    final displayDateStr = DateFormat('dd MMM yyyy').format(thursdayDate);
    final filename = 'Thursday_Standee_$dateStr.png';

    try {
      Uint8List? bytes;

      if (fullStandee && thursdayDate == _selectedThursday) {
        // Capture the rendered standee ID card for maximum fidelity (3x DPI)
        bytes = await _captureWidgetAsPng(_standeeCardKey);
      }

      // Fallback: standalone QR code render
      if (bytes == null) {
        final payload = _buildQrPayload(thursdayDate);
        bytes = await _renderQrToBytes(payload);
      }

      if (bytes != null) {
        await FileDownloadHelper.downloadPng(bytes, filename);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.image_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Downloaded Standee PNG for $displayDateStr ($filename)',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PNG: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  /// Downloads a single Thursday QR Standee (delegates to [_downloadThursdayPng]).
  Future<void> _downloadThursdayQr(
    DateTime thursdayDate, {
    bool fullStandee = true,
  }) async {
    await _downloadThursdayPng(thursdayDate, fullStandee: fullStandee);
  }

  /// Downloads all Thursdays for the currently selected month.
  Future<void> _downloadAllForCurrentMonth() async {
    final thursdays = _getThursdaysForMonth(_selectedMonth);
    if (thursdays.isEmpty) return;

    setState(() => _isDownloading = true);
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    try {
      int successCount = 0;
      for (final thursday in thursdays) {
        final dateStr = DateFormat('yyyy-MM-dd').format(thursday);
        final payload = _buildQrPayload(thursday);
        final bytes = await _renderQrToBytes(payload);
        if (bytes != null) {
          final filename = '$dateStr.png';
          await FileDownloadHelper.downloadPng(bytes, filename);
          successCount++;
          // Small delay to allow browser to process downloads smoothly
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Successfully downloaded all $successCount Thursday QRs for $monthName!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download monthly QRs: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  /// Captures a [RepaintBoundary] as high-resolution PNG bytes.
  Future<Uint8List?> _captureWidgetAsPng(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Generates a standalone QR PNG byte buffer using [QrPainter].
  Future<Uint8List?> _renderQrToBytes(String data) async {
    try {
      final painter = QrPainter(
        data: data,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0F172A),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0F172A),
        ),
      );
      final byteData = await painter.toImageData(
        800,
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 1st Logo: RISE Logo (Left) - Replaces TERM logo
  Widget _buildRiseLogo({required bool isDark, bool isCompact = false}) {
    final height = isCompact ? 48.0 : 58.0;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/images/RISE.png',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  /// 2nd Logo: Attendiphi by MetaPhi Logo (Middle)
  Widget _buildAttendiphiLogo({required bool isDark, bool isCompact = false}) {
    final height = isCompact ? 46.0 : 56.0;
    return Container(
      height: height,
      padding: isDark
          ? EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 2)
          : EdgeInsets.zero,
      decoration: isDark
          ? BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            )
          : null,
      child: Image.asset(
        'assets/images/attendiphi_logo.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  /// 3rd Logo: BNI Premier Logo (Right)
  Widget _buildBniPremierLogo({required bool isDark, bool isCompact = false}) {
    final height = isCompact ? 48.0 : 58.0;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/images/BNI.jpg',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  /// Top Header Bar of the ID Card containing all 3 logos:
  /// 1st: RISE logo | 2nd: Attendiphi by metaphi | 3rd: BNI premier logo
  Widget _buildIdCardHeader({required bool isDark, bool isCompact = false}) {
    final spacing = isCompact ? 10.0 : 14.0;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 2 : 4,
          vertical: isCompact ? 2 : 4,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1st: RISE Logo (replaces Term Logo)
              _buildRiseLogo(isDark: isDark, isCompact: isCompact),
              SizedBox(width: spacing),

              // 2nd: Attendiphi by metaphi (Middle)
              _buildAttendiphiLogo(isDark: isDark, isCompact: isCompact),
              SizedBox(width: spacing),

              // 3rd: BNI Premier Logo
              _buildBniPremierLogo(isDark: isDark, isCompact: isCompact),
            ],
          ),
        ),
      ),
    );
  }

  /// Authentic rectangular ID Card Standee widget.
  /// Features:
  /// - 3 Logos header bar (1st: RISE logo | 2nd: Attendiphi by metaphi | 3rd: BNI premier logo)
  /// - Status badge bar (Official Standee & Live/Upcoming/Locked)
  /// - Session title & validity date subtitle
  /// - High-contrast QR code container with centered MetaPhi logo
  /// - Scan instruction pill
  /// - Official ID card security footer
  Widget _buildIdCardStandee({
    required ThemeData theme,
    required DateTime thursdayDate,
    required int sessionNum,
    required bool isCurrentMonthActive,
    required bool isSelectedToday,
    required bool isSelectedPast,
    required bool isDark,
    required bool isMobile,
    required String payload,
  }) {
    final dayNum = DateFormat('dd').format(thursdayDate);
    final monthShort = DateFormat('MMM yyyy').format(thursdayDate);
    final weekdayName = DateFormat('EEEE').format(thursdayDate);

    return AppCard(
      elevation: 4,
      color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 18,
            vertical: isMobile ? 16 : 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top 3-Logos Header Bar
              // 1st: RISE Logo | 2nd: Attendiphi by metaphi | 3rd: BNI Premier Logo
              _buildIdCardHeader(isDark: isDark, isCompact: isMobile),

              const SizedBox(height: 14),

              // 3. Date Header
              Text(
                '$weekdayName, $dayNum $monthShort',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 14),

              // 5. Card Content: Active QR Frame VS Locked Notice Container
              if (isCurrentMonthActive) ...[
                // High-Contrast QR Frame
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.lgAll,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        size: isMobile ? 220.0 : 255.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/metaphi_logo.webp',
                          width: isMobile ? 64 : 74,
                          height: isMobile ? 19 : 23,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Footer Caption
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: AppRadius.fullAll,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 14,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Scan with phone camera to check in',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Locked State Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 26,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A).withAlpha(120)
                        : const Color(0xFFF8FAFC),
                    borderRadius: AppRadius.lgAll,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155).withAlpha(80)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0).withAlpha(120),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Icon(
                          Icons.lock_clock_rounded,
                          size: 26,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'QR Code Not Available Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Standee QR for ${DateFormat('MMMM yyyy').format(_selectedMonth)} will be generated and available when the month begins.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a modal dialog to view the QR Standee up-close.
  void _showQrViewModal(DateTime thursdayDate) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = context.isMobile;
    final dateFormatted = DateFormat('EEEE, dd MMMM yyyy').format(thursdayDate);
    final payload = _tryBuildQrPayload(thursdayDate);
    if (payload == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR Standee unavailable: rebuild with CHECKIN_SESSION_TOKEN_SECRET.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final thursdays = _getThursdaysForMonth(_selectedMonth);
    final selectedIndex = thursdays.indexWhere(
      (t) =>
          t.year == thursdayDate.year &&
          t.month == thursdayDate.month &&
          t.day == thursdayDate.day,
    );
    final sessionNum = selectedIndex >= 0 ? selectedIndex + 1 : 1;
    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      thursdayDate.year,
      thursdayDate.month,
      thursdayDate.day,
    );
    final isSelectedToday = selectedDay.isAtSameMomentAs(today);
    final isSelectedPast = !isSelectedToday && selectedDay.isBefore(today);
    final isCurrentMonthActive = _isMonthActive(thursdayDate);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: AppRadius.xlAll,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thursday QR Standee',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            dateFormatted,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(dialogCtx),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Standee ID Card Preview inside Modal
                _buildIdCardStandee(
                  theme: theme,
                  thursdayDate: thursdayDate,
                  sessionNum: sessionNum,
                  isCurrentMonthActive: isCurrentMonthActive,
                  isSelectedToday: isSelectedToday,
                  isSelectedPast: isSelectedPast,
                  isDark: isDark,
                  isMobile: isMobile,
                  payload: payload,
                ),

                const SizedBox(height: 18),

                // Modal Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy URL'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: payload));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'QR Check-in URL copied to clipboard!',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download PNG'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.mdAll,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          _downloadThursdayPng(thursdayDate);
                        },
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
  }

  Widget _buildPayloadConfigError(ThemeData theme, bool isDark) {
    return AppCard(
      elevation: 0,
      color: isDark
          ? const Color(0xFF7F1D1D).withAlpha(40)
          : const Color(0xFFFEF2F2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Standee unavailable',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Session QR codes could not be signed. Rebuild with '
                    './scripts/build_web_release.sh (injects CHECKIN_SESSION_TOKEN_SECRET) '
                    'and redeploy Hosting.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? const Color(0xFFFECACA)
                          : const Color(0xFF7F1D1D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompact = context.isCompactMobile;
    final dateRestricted = ref.watch(dateRestrictionEnabledProvider);

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final thursdays = _getThursdaysForMonth(
      _selectedMonth,
      dateRestricted: dateRestricted,
    );
    // Keep selection valid when switching Thursday-only ↔ everyday.
    if (thursdays.isNotEmpty &&
        !thursdays.any(
          (d) =>
              d.year == _selectedThursday.year &&
              d.month == _selectedThursday.month &&
              d.day == _selectedThursday.day,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedThursday = thursdays.first);
      });
    }
    final monthFormat = DateFormat('MMMM yyyy');
    final currentIndex = _availableMonths.indexWhere(
      (m) => m.year == _selectedMonth.year && m.month == _selectedMonth.month,
    );
    final hasPrevMonth = currentIndex > 0;
    final hasNextMonth = currentIndex < _availableMonths.length - 1;
    final isCurrentMonthActive = _isMonthActive(_selectedMonth);
    final selectedPayload = _tryBuildQrPayload(_selectedThursday);
    final payloadReady = selectedPayload != null;

    // Match other admin shell pages: Scaffold fills the branch navigator so
    // Column + Expanded always receive bounded height (avoids a blank body).
    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use the shell content pane width — not the full window — so the
          // sidebar does not force a broken desktop toolbar layout.
          final contentWidth = constraints.maxWidth;
          final isMobile = contentWidth < 850;
          final useSplitLayout = contentWidth >= 900;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: hPadding,
                  vertical: isMobile ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Sticky Top Header Bar & Month Toolbar (Anchored at Top Middle)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title and Subtitle (Desktop/Tablet only; on mobile Shell AppBar shows screen title)
                        if (!isMobile) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Thursday QR Standees',
                                style:
                                    (isMobile
                                            ? theme.textTheme.titleLarge
                                            : theme.textTheme.headlineMedium)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.6,
                                        ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select a month (Sep 2026 – Sep 2027) to view & download unique Thursday QR standees.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: isMobile ? 12 : 13.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Month Selector & Bulk Actions Toolbar (Sticky at Top Middle)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? theme.colorScheme.surfaceContainerHigh
                                : Colors.white,
                            borderRadius: AppRadius.lgAll,
                            border: Border.all(
                              color: isDark
                                  ? theme.colorScheme.outlineVariant.withAlpha(
                                      80,
                                    )
                                  : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 30 : 6),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildMonthNavButton(
                                          icon: Icons.chevron_left_rounded,
                                          onPressed: hasPrevMonth
                                              ? _selectPreviousMonth
                                              : null,
                                          tooltip: 'Previous Month',
                                          isDark: isDark,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildMonthDropdown(theme),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildMonthNavButton(
                                          icon: Icons.chevron_right_rounded,
                                          onPressed: hasNextMonth
                                              ? _selectNextMonth
                                              : null,
                                          tooltip: 'Next Month',
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      icon: _isDownloading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              isCurrentMonthActive
                                                  ? Icons
                                                        .download_for_offline_rounded
                                                  : Icons.lock_outline_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        isCurrentMonthActive
                                            ? 'Download All (${thursdays.length} QRs)'
                                            : 'QR Available in ${DateFormat('MMM').format(_selectedMonth)}',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCurrentMonthActive
                                            ? AppColors.primary
                                            : (isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFF94A3B8)),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        elevation: isCurrentMonthActive ? 2 : 0,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: AppRadius.mdAll,
                                        ),
                                      ),
                                      onPressed:
                                          (isCurrentMonthActive &&
                                              payloadReady &&
                                              !_isDownloading)
                                          ? _downloadAllForCurrentMonth
                                          : null,
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    // Previous Month Arrow (Fixed width)
                                    _buildMonthNavButton(
                                      icon: Icons.chevron_left_rounded,
                                      onPressed: hasPrevMonth
                                          ? _selectPreviousMonth
                                          : null,
                                      tooltip: 'Previous Month',
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 6),

                                    // Month Dropdown (Generous fixed width: 250px)
                                    SizedBox(
                                      width: 250,
                                      child: _buildMonthDropdown(theme),
                                    ),

                                    const SizedBox(width: 6),

                                    // Next Month Arrow (Fixed width)
                                    _buildMonthNavButton(
                                      icon: Icons.chevron_right_rounded,
                                      onPressed: hasNextMonth
                                          ? _selectNextMonth
                                          : null,
                                      tooltip: 'Next Month',
                                      isDark: isDark,
                                    ),

                                    const SizedBox(width: 12),

                                    // Thursdays Count Badge
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withAlpha(80)
                                              : const Color(0xFFF8FAFC),
                                          borderRadius: AppRadius.fullAll,
                                          border: Border.all(
                                            color: isDark
                                                ? theme
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withAlpha(60)
                                                : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 13,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '${thursdays.length} Thursdays in ${monthFormat.format(_selectedMonth)}',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Bulk Download Month QRs Button (Anchored to right)
                                    ElevatedButton.icon(
                                      icon: _isDownloading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              isCurrentMonthActive
                                                  ? Icons
                                                        .download_for_offline_rounded
                                                  : Icons.lock_outline_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        isCurrentMonthActive
                                            ? 'Download All (${thursdays.length} QRs)'
                                            : 'QR Available in ${DateFormat('MMM').format(_selectedMonth)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCurrentMonthActive
                                            ? AppColors.primary
                                            : (isDark
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFF94A3B8)),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 11,
                                        ),
                                        elevation: isCurrentMonthActive ? 2 : 0,
                                        shadowColor: isCurrentMonthActive
                                            ? AppColors.primary.withAlpha(80)
                                            : Colors.transparent,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: AppRadius.mdAll,
                                        ),
                                      ),
                                      onPressed:
                                          (isCurrentMonthActive &&
                                              payloadReady &&
                                              !_isDownloading)
                                          ? _downloadAllForCurrentMonth
                                          : null,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 2. Scrollable Content Area
                    Expanded(
                      child: !payloadReady
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _buildPayloadConfigError(theme, isDark),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: useSplitLayout
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Left Column: Thursdays List for Selected Month (50%)
                                        Expanded(
                                          flex: 1,
                                          child: _buildThursdaysList(
                                            theme,
                                            thursdays,
                                          ),
                                        ),
                                        const SizedBox(width: 24),

                                        // Right Column: Standee Preview for Selected Thursday (50%)
                                        Expanded(
                                          flex: 1,
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            child: _buildStandeePreviewCard(
                                              theme,
                                              isDark,
                                              isMobile,
                                              isCompact,
                                              thursdays,
                                              payload: selectedPayload,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Mobile: compact Thursday date selector (no list cards)
                                        if (isMobile)
                                          _buildMobileDateSelector(
                                            theme,
                                            isDark,
                                            thursdays,
                                          )
                                        else
                                          _buildThursdaysList(theme, thursdays),
                                        const SizedBox(height: 16),
                                        _buildStandeePreviewCard(
                                          theme,
                                          isDark,
                                          isMobile,
                                          isCompact,
                                          thursdays,
                                          payload: selectedPayload,
                                        ),
                                      ],
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthNavButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        disabledColor: isDark ? Colors.white24 : Colors.black26,
        visualDensity: VisualDensity.compact,
        splashRadius: 18,
      ),
    );
  }

  Widget _buildMonthDropdown(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final monthFormat = DateFormat('MMMM yyyy');

    Widget buildDropdownItemRow(DateTime month) {
      final isActive = _isMonthActive(month);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 15,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              monthFormat.format(month),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(isDark ? 40 : 25),
                borderRadius: AppRadius.fullAll,
                border: Border.all(color: AppColors.success.withAlpha(60)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 5, color: AppColors.success),
                  SizedBox(width: 3),
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: _selectedMonth,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: AppRadius.lgAll,
          selectedItemBuilder: (BuildContext context) {
            return _availableMonths.map<Widget>(buildDropdownItemRow).toList();
          },
          items: _availableMonths.map((month) {
            return DropdownMenuItem<DateTime>(
              value: month,
              child: buildDropdownItemRow(month),
            );
          }).toList(),
          onChanged: (newMonth) {
            if (newMonth != null) {
              _onMonthChanged(newMonth);
            }
          },
        ),
      ),
    );
  }

  /// Compact Thursday date selector for mobile — replaces the session card list.
  Widget _buildMobileDateSelector(
    ThemeData theme,
    bool isDark,
    List<DateTime> thursdays,
  ) {
    if (thursdays.isEmpty) return const SizedBox.shrink();

    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentMonthActive = _isMonthActive(_selectedMonth);

    String thursdayLabel(DateTime t) {
      final day = DateFormat('dd MMM yyyy').format(t);
      final tDay = DateTime(t.year, t.month, t.day);
      if (!isCurrentMonthActive) return day;
      if (tDay.isAtSameMomentAs(today)) return '$day  • ACTIVE';
      if (tDay.isBefore(today)) return '$day  • PAST';
      return '$day  • UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outlineVariant.withAlpha(80)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 20 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 15,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                value: _selectedThursday,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: AppRadius.lgAll,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: thursdays.map((t) {
                  return DropdownMenuItem<DateTime>(
                    value: t,
                    child: Text(
                      thursdayLabel(t),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (picked) {
                  if (picked != null) {
                    setState(() => _selectedThursday = picked);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// List of Thursday cards for the active month.
  /// Separates previewed state with an elegant indigo/accent left border and clean typography.
  Widget _buildThursdaysList(ThemeData theme, List<DateTime> thursdays) {
    final isDark = theme.brightness == Brightness.dark;
    final isCurrentMonthActive = _isMonthActive(_selectedMonth);

    return AppCard(
      elevation: 3,
      color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.fullAll,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Thursday Schedule',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest.withAlpha(
                            80,
                          )
                        : const Color(0xFFF1F5F9),
                    borderRadius: AppRadius.fullAll,
                    border: Border.all(
                      color: isDark
                          ? theme.colorScheme.outlineVariant.withAlpha(60)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: thursdays.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final thursday = thursdays[index];
                final isSelected =
                    thursday.year == _selectedThursday.year &&
                    thursday.month == _selectedThursday.month &&
                    thursday.day == _selectedThursday.day;

                final now = _now;
                final today = DateTime(now.year, now.month, now.day);
                final thursdayDay = DateTime(
                  thursday.year,
                  thursday.month,
                  thursday.day,
                );

                final isSessionActive = thursdayDay.isAtSameMomentAs(today);
                final isToday = isSessionActive;
                final isPast = !isSessionActive && thursdayDay.isBefore(today);

                String statusLabel;
                Color statusBg;
                if (isToday) {
                  statusLabel = 'ACTIVE';
                  statusBg = AppColors.success;
                } else if (isPast) {
                  statusLabel = 'PAST';
                  statusBg = isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8);
                } else {
                  statusLabel = 'UPCOMING';
                  statusBg = const Color(0xFF6366F1);
                }

                final dayNum = DateFormat('dd').format(thursday);
                final monthShort = DateFormat('MMM yyyy').format(thursday);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedThursday = thursday;
                    });
                  },
                  borderRadius: AppRadius.mdAll,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC))
                          : (isDark
                                ? theme.colorScheme.surfaceContainerHighest
                                      .withAlpha(40)
                                : Colors.white),
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: isSelected
                            ? (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF334155))
                            : (isDark
                                  ? theme.colorScheme.outlineVariant.withAlpha(
                                      60,
                                    )
                                  : const Color(0xFFE2E8F0)),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 25 : 6),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // Left active indicator pill if selected
                        if (isSelected)
                          Container(
                            width: 3.5,
                            height: 38,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                        // Date Badge
                        Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0F172A)
                                : (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFF334155)),
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Column(
                            children: [
                              Text(
                                dayNum,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'THU',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(200),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Date Details & Payload snippet
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Session ${index + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: AppRadius.fullAll,
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Thursday, $dayNum $monthShort',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Secure /checkin link for ${DateFormat('yyyy-MM-dd').format(thursday)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons: View & Download
                        if (isCurrentMonthActive) ...[
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 19,
                            ),
                            tooltip: 'View QR Modal',
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            splashRadius: 18,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showQrViewModal(thursday),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.file_download_outlined,
                              size: 19,
                            ),
                            tooltip: 'Download QR PNG',
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            splashRadius: 18,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _downloadThursdayQr(thursday),
                          ),
                        ] else ...[
                          Tooltip(
                            message:
                                'QR unlocks in ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Interactive live Standee preview card showing the selected Thursday's QR code.
  /// Styled as an authentic, high-contrast, print-ready Standee card with direct actions.
  Widget _buildStandeePreviewCard(
    ThemeData theme,
    bool isDark,
    bool isMobile,
    bool isCompact,
    List<DateTime> thursdays, {
    required String payload,
  }) {
    final isCurrentMonthActive = _isMonthActive(_selectedMonth);

    final now = _now;
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      _selectedThursday.year,
      _selectedThursday.month,
      _selectedThursday.day,
    );
    final isSelectedActive = selectedDay.isAtSameMomentAs(today);
    final isSelectedToday = isSelectedActive;
    final isSelectedPast = !isSelectedActive && selectedDay.isBefore(today);

    final selectedIndex = thursdays.indexWhere(
      (t) =>
          t.year == _selectedThursday.year &&
          t.month == _selectedThursday.month &&
          t.day == _selectedThursday.day,
    );
    final sessionNum = selectedIndex >= 0 ? selectedIndex + 1 : 1;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedThursday);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _standeeCardKey,
          child: _buildIdCardStandee(
            theme: theme,
            thursdayDate: _selectedThursday,
            sessionNum: sessionNum,
            isCurrentMonthActive: isCurrentMonthActive,
            isSelectedToday: isSelectedToday,
            isSelectedPast: isSelectedPast,
            isDark: isDark,
            isMobile: isMobile,
            payload: payload,
          ),
        ),
        if (isCurrentMonthActive) ...[
          const SizedBox(height: 12),
          // Raw Payload String with Copy Button
          Container(
            padding: const EdgeInsets.only(
              left: 10,
              right: 3,
              top: 2,
              bottom: 2,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Secure session link',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  splashRadius: 14,
                  tooltip: 'Copy secure check-in URL',
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: payload));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Copied secure check-in URL for Session $sessionNum ($dateStr)',
                              ),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Direct Action Buttons on Standee Card
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.fullscreen_rounded, size: 17),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  onPressed: () => _showQrViewModal(_selectedThursday),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text(
                    'Download PNG',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 1,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  onPressed: () => _downloadThursdayPng(_selectedThursday),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 16),
          // Disabled Action Buttons for Locked Card
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.fullscreen_rounded, size: 17),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onPressed: null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline_rounded, size: 17),
                  label: Text(
                    'Available in ${DateFormat('MMM').format(_selectedMonth)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                    foregroundColor: isDark
                        ? Colors.white38
                        : const Color(0xFF94A3B8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  onPressed: null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
