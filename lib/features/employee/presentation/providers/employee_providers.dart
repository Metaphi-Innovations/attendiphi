import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/repositories/employee_repository_impl.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

/// Provider for [EmployeeRemoteDataSource].
final employeeRemoteDataSourceProvider =
    Provider<EmployeeRemoteDataSource>((ref) {
  return EmployeeRemoteDataSourceImpl(ref.watch(firestoreProvider));
});

/// Provider for [EmployeeRepository].
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(ref.watch(employeeRemoteDataSourceProvider));
});

/// Stream provider for the full employee roster (admin-authenticated reads).
final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  ref.keepAlive();
  final repository = ref.watch(employeeRepositoryProvider);
  return repository.streamEmployees();
});

/// Public QR typeahead directory (id / name / phone / isActive only).
final publicMembersStreamProvider = StreamProvider<List<Employee>>((ref) {
  ref.keepAlive();
  final repository = ref.watch(employeeRepositoryProvider);
  return repository.streamPublicMembers();
});

/// Server-first fetch of one member document by id. Used by the Successful
/// screen so a stale Firestore cache cannot display an old name.
final employeeByIdProvider =
    FutureProvider.family<Employee?, String>((ref, id) async {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return null;
  return ref.watch(employeeRepositoryProvider).getEmployee(trimmed);
});
