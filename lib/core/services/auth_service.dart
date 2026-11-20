import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/models.dart';

/// Supabase auth wrapper: email/password sign-up, sign-in, sign-out and
/// session state. Additional providers (Apple/Google) plug in here.
class AuthService extends ChangeNotifier {
  /// Initialized in [init]: the Supabase singleton client whose session
  /// is persisted by supabase_flutter (survives app restarts).
  late final SupabaseClient client;

  bool _initialized = false;
  bool _busy = false;
  String? _error;

  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get error => _error;
  bool get signedIn => client.auth.currentSession != null;

  String? get userId => client.auth.currentUser?.id;

  /// Restores a persisted session; call once on app start.
  Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    client = Supabase.instance.client;
    _initialized = true;
    client.auth.onAuthStateChange.listen((_) => notifyListeners());
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) =>
      _guard(() => client.auth.signInWithPassword(
            email: email,
            password: password,
          ));

  Future<bool> signUp(String email, String password) =>
      _guard(() => client.auth.signUp(email: email, password: password));

  Future<void> signOut() async {
    await client.auth.signOut();
    notifyListeners();
  }

  Future<bool> _guard(Future<AuthResponse> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Netzwerkfehler: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ---- Manage profiles (multi user within one account) ------------------

  Future<List<UserProfile>> fetchProfiles() async {
    final uid = userId;
    if (uid == null) return const [];
    final rows = await client
        .from('profiles')
        .select()
        .eq('user_id', uid)
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

  Future<void> addProfile(String name, {bool kids = false}) async {
    await client.from('profiles').insert({
      'user_id': userId!,
      'name': name,
      'is_kids': kids,
    });
  }

  Future<void> deleteProfile(String profileId) async {
    await client.from('profiles').delete().eq('id', profileId);
  }
}
