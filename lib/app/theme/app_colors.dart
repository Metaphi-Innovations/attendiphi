import 'package:flutter/material.dart';

/// Application semantic color palette.
///
/// Clean, modern SaaS design system with Indigo/Blue brand identity,
/// slate neutrals, emerald success, amber warning, and crisp surfaces.
class AppColors {
  AppColors._();

  // ── Brand Primary (Indigo) ─────────────────────────────────────────────
  static const primary = Color(0xFF4F46E5);
  static const primaryHover = Color(0xFF4338CA);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF3730A3);
  static const primaryContainer = Color(0xFFEEF2FF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF312E81);

  // ── Secondary / Slate ──────────────────────────────────────────────────
  static const secondary = Color(0xFF475569);
  static const secondaryLight = Color(0xFF64748B);
  static const secondaryDark = Color(0xFF334155);
  static const onSecondary = Color(0xFFFFFFFF);

  // ── Semantic Status Colors ─────────────────────────────────────────────
  // Success / Member / On-site (Emerald Green)
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const successDark = Color(0xFF059669);
  static const onSuccess = Color(0xFFFFFFFF);
  static const onSuccessContainer = Color(0xFF065F46);

  // Warning / Substitute (Amber Orange)
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const warningDark = Color(0xFFD97706);
  static const onWarning = Color(0xFF1F2937);
  static const onWarningContainer = Color(0xFF92400E);

  // Error / Destructive (Red)
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const errorDark = Color(0xFFDC2626);
  static const onError = Color(0xFFFFFFFF);
  static const onErrorContainer = Color(0xFF991B1B);

  // Info / Blue
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDBEAFE);
  static const infoDark = Color(0xFF1D4ED8);
  static const onInfo = Color(0xFFFFFFFF);
  static const onInfoContainer = Color(0xFF1E40AF);

  // Location / Purple
  static const location = Color(0xFF8B5CF6);
  static const locationLight = Color(0xFFEDE9FE);
  static const locationDark = Color(0xFF6D28D9);

  // ── Light Theme Surfaces & Backgrounds ─────────────────────────────────
  static const backgroundLight = Color(0xFFF8FAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceVariantLight = Color(0xFFF1F5F9);
  static const surfaceSubtleLight = Color(0xFFF8FAFC);
  static const onSurfaceLight = Color(0xFF0F172A);
  static const onSurfaceVariantLight = Color(0xFF64748B);
  static const onSurfaceMutedLight = Color(0xFF94A3B8);

  // ── Dark Theme Surfaces & Backgrounds ──────────────────────────────────
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceVariantDark = Color(0xFF334155);
  static const surfaceSubtleDark = Color(0xFF1E293B);
  static const onSurfaceDark = Color(0xFFF8FAFC);
  static const onSurfaceVariantDark = Color(0xFF94A3B8);
  static const onSurfaceMutedDark = Color(0xFF64748B);

  // ── Borders & Outlines ─────────────────────────────────────────────────
  static const outlineLight = Color(0xFFE2E8F0);
  static const outlineVariantLight = Color(0xFFCBD5E1);
  static const outlineDark = Color(0xFF334155);
  static const outlineVariantDark = Color(0xFF475569);

  // ── Shimmer / Skeleton ─────────────────────────────────────────────────
  static const shimmerBase = Color(0xFFE2E8F0);
  static const shimmerHighlight = Color(0xFFF8FAFC);
  static const shimmerBaseDark = Color(0xFF334155);
  static const shimmerHighlightDark = Color(0xFF475569);

  // ── Overlay ────────────────────────────────────────────────────────────
  static const scrim = Color(0x80000000);
}
