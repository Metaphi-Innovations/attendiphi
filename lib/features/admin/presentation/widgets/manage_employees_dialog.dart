import 'package:flutter/material.dart';

/// Legacy dialog placeholder kept for backwards compatibility.
/// Superseded by modern [UserManagementScreen].
@Deprecated('Use UserManagementScreen instead')
class ManageEmployeesDialog extends StatelessWidget {
  const ManageEmployeesDialog({super.key});

  static void show(BuildContext context) {
    // No-op: replaced by Member Management tab
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
