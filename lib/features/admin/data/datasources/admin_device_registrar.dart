/// Registers admin push tokens and listens/polls for attendance alerts.
abstract class AdminDeviceRegistrar {
  Future<void> registerAdminDevice({required String adminEmail, String? uid});

  Future<void> unregisterAdminDevice();

  void dispose();
}
