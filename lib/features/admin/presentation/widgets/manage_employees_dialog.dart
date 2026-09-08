import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../providers/admin_auth_provider.dart';
import '../providers/admin_scope_provider.dart';

/// Modal dialog / bottom sheet allowing admins to Add, Update, and Delete employees.
class ManageEmployeesDialog extends ConsumerStatefulWidget {
  const ManageEmployeesDialog({super.key});

  static void show(BuildContext context) {
    final isDesktop = context.isDesktop || context.isTablet;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
            child: const ManageEmployeesDialog(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: const ManageEmployeesDialog(),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<ManageEmployeesDialog> createState() => _ManageEmployeesDialogState();
}

class _ManageEmployeesDialogState extends ConsumerState<ManageEmployeesDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({Employee? existingEmployee}) {
    final nameController =
        TextEditingController(text: existingEmployee?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = existingEmployee != null;

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: Row(
          children: [
            Icon(
              isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(isEditing ? 'Edit Member Name' : 'Add New Member'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: nameController,
                label: 'Member Full Name',
                hint: 'e.g. Omkar',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                autofocus: true,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a valid name';
                  }
                  if (val.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final name = nameController.text.trim();
              Navigator.pop(ctx);

              try {
                final activeScope = ref.read(activeAdminScopeProvider);
                final isSuperAdmin = ref.read(isSuperAdminProvider);
                final currentAdmin = ref.read(currentAdminUserProvider);
                final targetAdminId = activeScope?.id ??
                    (isSuperAdmin ? null : currentAdmin?.id);

                final repo = ref.read(employeeRepositoryProvider);
                if (isEditing) {
                  await repo.updateEmployee(
                    existingEmployee.id,
                    name,
                    adminId: existingEmployee.adminId ?? targetAdminId,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Updated "$name" successfully'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  await repo.addEmployee(name, adminId: targetAdminId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "$name" to employee list'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Add Employee'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Employee employee) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Delete Employee?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${employee.name}" from the employee dropdown list?\n\nThey will no longer appear in the check-in dropdown menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(employeeRepositoryProvider).deleteEmployee(employee.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Deleted "${employee.name}"'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employeesAsync = ref.watch(employeesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
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
                      'Manage Employee List',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'These names appear in the check-in dropdown menu',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search + Add Button Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search employee...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.mdAll,
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _showAddEditDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Member'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Employees List
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Failed to load employees: $err',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              data: (employees) {
                final filtered = employees.where((emp) {
                  if (_searchQuery.isEmpty) return true;
                  return emp.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      emp.phone.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No employee matching "$_searchQuery"'
                              : 'No employees registered yet',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isEmpty)
                          TextButton.icon(
                            onPressed: _showAddEditDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Employee'),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final employee = filtered[index];
                    return AppCard(
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          employee.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: employee.phone.isNotEmpty
                            ? Text(
                                employee.phone,
                                style: const TextStyle(fontSize: 12),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit name',
                              onPressed: () => _showAddEditDialog(
                                existingEmployee: employee,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.error,
                              ),
                              tooltip: 'Delete employee',
                              onPressed: () => _confirmDelete(employee),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
