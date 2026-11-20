import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/models.dart';
import 'backend.dart';

/// Supabase cloud backend (https://supabase.com project).
class SupabaseBackend implements Backend {
  late final SupabaseClient client;
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    } catch (_) {
      // already initialized (hot reload / second call)
    }
    client = Supabase.instance.client;
    _initialized = true;
  }

  @override
  bool get signedIn => _initialized && client.auth.currentSession != null;

  @override
  String? get userId => client.auth.currentUser?.id;

  @override
  String? get userEmail => client.auth.currentUser?.email;

  void _require() {
    if (!signedIn) throw const BackendException('Nicht angemeldet');
  }

  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password) async {
    await client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signOut() => client.auth.signOut();

  @override
  Future<List<UserProfile>> fetchProfiles() async {
    _require();
    final rows = await client
        .from('profiles')
        .select()
        .eq('user_id', userId!)
        .order('created_at');
    return rows
        .map<UserProfile>((r) => UserProfile(
              id: r['id'].toString(),
              name: r['name'].toString(),
              avatarColor: r['avatar_color']?.toString() ?? '#4F8CFF',
              isKids: (r['is_kids'] as bool?) ?? false,
            ))
        .toList();
  }

  @override
  Future<void> addProfile(String name, {bool kids = false}) async {
    _require();
    await client.from('profiles').insert({
      'user_id': userId!,
      'name': name,
      'is_kids': kids,
    });
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    _require();
    await client.from('profiles').delete().eq('id', profileId);
  }

  @override
  Future<PullResult> pull(String profileId, Map<String, String> cursors) async {
    String since(String table) => cursors[table] ?? '1970-01-01T00:00:00Z';

    final favorites = await client
        .from('favorites')
        .select()
        .eq('profile_id', profileId)
        .gt('updated_at', since('favorites'));
    final progress = await client
        .from('watch_progress')
        .select()
        .eq('profile_id', profileId)
        .gt('updated_at', since('watch_progress'));
    final views = await client
        .from('views')
        .select()
        .eq('profile_id', profileId)
        .gt('updated_at', since('views'));

    return PullResult(
      favorites: List<Map<String, dynamic>>.from(favorites),
      watchProgress: List<Map<String, dynamic>>.from(progress),
      views: List<Map<String, dynamic>>.from(views),
    );
  }

  @override
  Future<void> push(String profileId, PushPayload payload) async {
    for (final pl in payload.playlists) {
      await client.from('playlists').upsert({
        'profile_id': profileId,
        ...pl,
      });
    }
    for (final f in payload.favorites) {
      await client.from('favorites').upsert({
        'profile_id': profileId,
        ...f,
      }, onConflict: 'profile_id,item_kind,item_id,state');
    }
    for (final p in payload.watchProgress) {
      await client.from('watch_progress').upsert({
        'profile_id': profileId,
        ...p,
      }, onConflict: 'profile_id,item_kind,item_id');
    }
    for (final v in payload.views) {
      await client.from('views').upsert({
        'profile_id': profileId,
        ...v,
      }, onConflict: 'profile_id,item_kind,item_id');
    }
  }
}
