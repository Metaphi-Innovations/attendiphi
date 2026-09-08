import 'package:flutter/material.dart';

/// Design system elevation shadows.
///
/// Subtle, refined elevation tokens for modern SaaS interfaces.
class AppShadows {
  AppShadows._();

  /// No elevation
  static const List<BoxShadow> none = [];

  /// Subtle elevation for cards, dropdowns, and items on hover
  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  /// Standard card elevation
  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0F000000),
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -1,
    ),
  ];

  /// High elevation for floating panels, dialogs, and popovers
  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];

  /// Extra large elevation for modal dialogs and sheets
  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x26000000),
      offset: Offset(0, 20),
      blurRadius: 25,
      spreadRadius: -5,
    ),
  ];
}
