import '../models/models.dart';

/// Thrown by backends for foreseeable errors; message is user-facing.
class BackendException implements Exception {
  final String message;
  const BackendException(this.message);

  @override
  String toString() => message;
}

/// Rows for one sync direction. Keys/columns use snake_case to match the
/// database so both backends (Supabase + self-hosted REST) share one shape.
class PushPayload {
  final List<Map<String, dynamic>> playlists;
  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> watchProgress;
  final List<Map<String, dynamic>> views;

  const PushPayload({
    this.playlists = const [],
    this.favorites = const [],
    this.watchProgress = const [],
    this.views = const [],
  });
}

class PullResult {
  final List<Map<String, dynamic>> favorites;
  final List<Map<String, dynamic>> watchProgress;
  final List<Map<String, dynamic>> views;

  const PullResult({
    this.favorites = const [],
    this.watchProgress = const [],
    this.views = const [],
  });
}

/// Storage/sync backend abstraction.
/// Implementations: [SupabaseBackend] (Supabase cloud) and
/// [RestBackend] (self-hosted: docker compose with Postgres + sync server).
abstract class Backend {
  Future<void> init();

  bool get signedIn;
  String? get userId;
  String? get userEmail;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> signOut();

  Future<List<UserProfile>> fetchProfiles();
  Future<void> addProfile(String name, {bool kids = false});
  Future<void> deleteProfile(String profileId);

  /// Pull rows for [profileId] newer than the per-table cursors.
  Future<PullResult> pull(String profileId, Map<String, String> cursors);

  /// Push local rows for [profileId] (profile_id is added by the backend).
  Future<void> push(String profileId, PushPayload payload);
}
