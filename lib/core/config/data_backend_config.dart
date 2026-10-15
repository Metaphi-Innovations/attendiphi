/// Attendiphi runs on Supabase only (project `fzghxzybyygslfjyfewu`).
///
/// Legacy `USE_SUPABASE_*` dart-defines are ignored; getters always return true
/// so call sites compile until fully deleted.
class DataBackendConfig {
  DataBackendConfig._();

  static const useSupabaseData = true;
  static const useSupabaseAuth = true;

  static bool get isSupabaseDataEnabled => true;
  static bool get isSupabaseAuthEnabled => true;
  static bool get useSupabaseAdmins => true;
}
