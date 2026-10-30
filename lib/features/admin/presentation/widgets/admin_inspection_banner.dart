import 'package:flutter/material.dart';

/// Legacy inspection banner placeholder.
/// With the unified database architecture, workspace isolation has been removed
/// and all admins and super admins operate on the same unified database.
class AdminInspectionBanner extends StatelessWidget {
  const AdminInspectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
