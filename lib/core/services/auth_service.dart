import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../backend/backend.dart';
import '../backend/backend.dart' as bk;
import '../backend/local_backend.dart';
import '../backend/rest_backend.dart';
import 'settings_service.dart';

/// Auth + profile facade over the active backend (offline/local by default,
/// optional sync account set up in Settings). UI only talks to this class.
class AuthService extends ChangeNotifier {
  final BackendRouter backend;
  final SettingsService settings;
  final Backend local; // offline fallback, kept for switching back

  AuthService(this.backend, this.settings, this.local);

  static const _kServer = 'sync.server';
  static const _kUsername = 'sync.username';

  bool _busy = false;
  String? _error;
  List<UserProfile>? _profiles;

  bool get busy => _busy;
  String? get error => _error;
  bool get signedIn => backend.signedIn;
  String? get userId => backend.userId;
  String? get userLabel => backend.userEmail;
  bool get syncEnabled => backend.userId != 'local';

  bool get syncingRemote => false;

  // ---- Optional sync setup ------------------------------------------------

  Future<String?> serverUrl() => settings.get(_kServer);

  Future<String?> serverUsername() => settings.get(_kUsername);

  RestBackend _for(String url) => RestBackend(_normalize(url));

  static String _normalize(String url) {
    url = url.trim();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Restores a previously configured sync session at app start; silently
  /// stays in offline mode on failure.
  Future<void> restoreSync() async {
    final url = await settings.get(_kServer);
    if (url == null || url.isEmpty) return;
    try {
      await backend.use(_for(url));
    } catch (_) {
      await backend.use(local);
    }
    notifyListeners();
  }

  /// Enables sync: creates/uses an account identified by [username] only
  /// (password optional), then migrates existing local profiles + their data
  /// onto the account.
  Future<bool> connectSync(String url, String username, String password) async {
    return _guard(() async {
      final rest = _for(url);
      await rest.init();
      try {
        await rest.signIn(username, password);
      } on bk.BackendException {
        await rest.signUp(username, password);
      }
      await _migrateTo(rest);
      await rest.init();
      await backend.use(rest);
      await settings.set(_kServer, _normalize(url));
      await settings.set(_kUsername, username.trim());
    });
  }

  Future<void> _migrateTo(RestBackend rest) async {
    final localBackend = local as LocalBackend;
    final localProfiles = await localBackend.fetchProfiles();

    // Keep empty auto-seeded default profiles out of the remote account.
    final keep = <UserProfile>[];
    for (final p in localProfiles) {
      if (await localBackend.hasData(p.id)) {
        keep.add(p);
      } else {
        await localBackend.deleteProfile(p.id);
      }
    }

    // Fetch or create the remote counterpart of every local profile and
    // re-key existing local rows so they belong to the remote profile id.
    final remote = await rest.fetchProfiles();

    for (final lp in keep) {
      UserProfile? target;
      for (final r in remote) {
        if (r.name == lp.name) {
          target = r;
          break;
        }
      }
      target ??= await _remoteProfileByName(rest, lp.name);
      target ??= await () async {
        await rest.addProfile(lp.name, kids: lp.isKids);
        return _remoteProfileByName(rest, lp.name);
      }();
      if (target != null) {
        await localBackend.migrateProfile(lp.id, target.id);
      }
    }
  }

  Future<UserProfile?> _remoteProfileByName(
      RestBackend rest, String name) async {
    for (final r in await rest.fetchProfiles()) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// Back to offline mode; the server account itself is untouched.
  Future<bool> disconnectSync() async {
    return _guard(() async {
      await backend.use(local);
      await settings.set(_kServer, '');
      await settings.set(_kUsername, '');
      await settings.db.setMeta('active_profile_id', '');
    });
  }

  // ---- Generic -----------------------------------------------------------

  Future<bool> _guard(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on bk.BackendException catch (e) {
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

  // ---- Profiles (multi user within one account) ---------------------------

  List<UserProfile>? get cachedProfiles => _profiles;

  Future<List<UserProfile>> fetchProfiles() async {
    _profiles = await backend.fetchProfiles();
    return _profiles!;
  }

  Future<void> addProfile(String name, {bool kids = false}) async {
    await backend.addProfile(name, kids: kids);
    _profiles = null;
    notifyListeners();
  }

  Future<void> deleteProfile(String profileId) async {
    await backend.deleteProfile(profileId);
    _profiles = null;
    notifyListeners();
  }
}
