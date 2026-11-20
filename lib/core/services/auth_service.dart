import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../backend/backend.dart';

/// Auth + profile facade over the selected backend (self-hosted REST by
/// default, Supabase cloud optional). UI only talks to this class.
class AuthService extends ChangeNotifier {
  final Backend backend;

  AuthService(this.backend);

  bool _busy = false;
  bool _initialized = false;
  String? _error;

  bool get initialized => _initialized;
  bool get busy => _busy;
  String? get error => _error;
  bool get signedIn => backend.signedIn;
  String? get userId => backend.userId;
  String? get userEmail => backend.userEmail;

  /// Establishes the backend (session restore); idempotent.
  Future<void> init() async {
    await backend.init();
    _initialized = true;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) =>
      _guard(() => backend.signIn(email, password));

  Future<bool> signUp(String email, String password) =>
      _guard(() => backend.signUp(email, password));

  Future<void> signOut() async {
    await backend.signOut();
    notifyListeners();
  }

  Future<bool> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on BackendException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Verbindung fehlgeschlagen: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ---- Profiles (multi user within one account) -------------------------

  Future<List<UserProfile>> fetchProfiles() => backend.fetchProfiles();

  Future<void> addProfile(String name, {bool kids = false}) async {
    await backend.addProfile(name, kids: kids);
    notifyListeners();
  }

  Future<void> deleteProfile(String profileId) async {
    await backend.deleteProfile(profileId);
    notifyListeners();
  }
}
