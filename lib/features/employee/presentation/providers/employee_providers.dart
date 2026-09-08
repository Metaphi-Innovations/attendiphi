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

/// Stream provider for the list of employees / members across the unified database.
final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  ref.keepAlive();
  final repository = ref.watch(employeeRepositoryProvider);
  return repository.streamEmployees();
});
