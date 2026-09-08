import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Legacy inspection banner placeholder.
/// With the unified database architecture, workspace isolation has been removed
/// and all admins and super admins operate on the same unified database.
class AdminInspectionBanner extends ConsumerWidget {
  const AdminInspectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
