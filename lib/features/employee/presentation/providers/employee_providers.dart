import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../../admin/presentation/providers/admin_auth_provider.dart';
import '../../data/datasources/employee_remote_data_source.dart';
import '../../data/datasources/supabase_employee_remote_data_source.dart';
import '../../data/repositories/employee_repository_impl.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';

/// Provider for [EmployeeRemoteDataSource] (Postgres `members`).
final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>((
  ref,
) {
  if (!SupabaseBootstrap.isInitialized) {
    throw const ServerException(
      technicalMessage: 'Supabase is not initialized (employees)',
    );
  }
  AppLogger.info('Employee data source: Supabase', tag: 'EmployeeProviders');
  return SupabaseEmployeeRemoteDataSource();
});

/// Provider for [EmployeeRepository].
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepositoryImpl(ref.watch(employeeRemoteDataSourceProvider));
});

/// Stream provider for the full employee roster (admin-authenticated reads).
final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  final auth = ref.watch(adminAuthProvider);
  if (!auth.sessionResolved) {
    return pendingStreamController<List<Employee>>(onDispose: ref.onDispose)
        .stream;
  }
  if (!auth.isAuthenticated) {
    return Stream.value(const <Employee>[]);
  }
  final repository = ref.watch(employeeRepositoryProvider);
  return repository.streamEmployees();
});

/// Public QR typeahead directory (id / name / phone / isActive only).
final publicMembersStreamProvider = StreamProvider<List<Employee>>((ref) {
  final repository = ref.watch(employeeRepositoryProvider);
  return repository.streamPublicMembers();
});

/// Face check-in candidates (active members with SFace templates). Works on public QR.
final faceVerificationCandidatesProvider = StreamProvider<List<Employee>>((
  ref,
) {
  final repository = ref.watch(employeeRepositoryProvider);
  return repository.streamFaceVerificationCandidates();
});

/// Server-first fetch of one member document by id.
final employeeByIdProvider = FutureProvider.family<Employee?, String>((
  ref,
  id,
) async {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return null;
  return ref.watch(employeeRepositoryProvider).getEmployee(trimmed);
});
