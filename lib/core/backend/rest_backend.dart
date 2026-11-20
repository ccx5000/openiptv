import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';
import 'backend.dart';

/// Self-hosted backend: talks to the small REST sync server that ships in
/// `docker/server/` (docker compose up → Postgres + Node server on :8080).
class RestBackend implements Backend {
  final String baseUrl;
  RestBackend(this.baseUrl);

  final http.Client _http = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _token;
  String? _userId;
  String? _email;

  static const _kToken = 'rest_token';
  static const _kUserId = 'rest_user_id';
  static const _kEmail = 'rest_user_email';

  @override
  Future<void> init() async {
    _token = await _storage.read(key: _kToken);
    _userId = await _storage.read(key: _kUserId);
    _email = await _storage.read(key: _kEmail);
  }

  @override
  bool get signedIn => _token != null && _userId != null;

  @override
  String? get userId => _userId;

  @override
  String? get userEmail => _email;

  void _require() {
    if (!signedIn) throw const BackendException('Nicht angemeldet');
  }

  Future<Map<String, String>> _headers() async {
    _require();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final res = await _http.request(
      uri,
      method: method,
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    final text = res.body.isEmpty ? '{}' : res.body;
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw BackendException(
          json['error']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    return json;
  }

  Future<void> _storeSession(
      String token, String uid, String? email) async {
    _token = token;
    _userId = uid;
    _email = email;
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUserId, value: uid);
    if (email != null) await _storage.write(key: _kEmail, value: email);
  }

  @override
  Future<void> signIn(String email, String password) async {
    final j = await _unauthCall(
        'POST', '/auth/login', {'email': email, 'password': password});
    await _storeSession(j['token'].toString(), j['userId'].toString(), email);
  }

  @override
  Future<void> signUp(String email, String password) async {
    final j = await _unauthCall(
        'POST', '/auth/register', {'email': email, 'password': password});
    await _storeSession(j['token'].toString(), j['userId'].toString(), email);
  }

  Future<Map<String, dynamic>> _unauthCall(
      String method, String path, Object body) async {
    final res = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final json =
        jsonDecode(res.body.isEmpty ? '{}' : res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw BackendException(
          json['error']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    return json;
  }

  @override
  Future<void> signOut() async {
    _token = null;
    _userId = null;
    _email = null;
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kEmail);
  }

  @override
  Future<List<UserProfile>> fetchProfiles() async {
    final rows = await _call('GET', '/profiles') as List<dynamic>;
    return List<Map<String, dynamic>>.from(rows)
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
    await _call('POST', '/profiles', body: {'name': name, 'is_kids': kids});
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    await _call('DELETE', '/profiles/$profileId');
  }

  @override
  Future<PullResult> pull(String profileId, Map<String, String> cursors) async {
    final j = await _call('GET', '/sync/$profileId', query: {
      'since_favorites': cursors['favorites'] ?? '1970-01-01T00:00:00Z',
      'since_watch_progress':
          cursors['watch_progress'] ?? '1970-01-01T00:00:00Z',
      'since_views': cursors['views'] ?? '1970-01-01T00:00:00Z',
    });
    return PullResult(
      favorites: List<Map<String, dynamic>>.from(j['favorites'] ?? const []),
      watchProgress:
          List<Map<String, dynamic>>.from(j['watch_progress'] ?? const []),
      views: List<Map<String, dynamic>>.from(j['views'] ?? const []),
    );
  }

  @override
  Future<void> push(String profileId, PushPayload payload) async {
    await _call('POST', '/sync/$profileId', body: {
      'playlists': payload.playlists,
      'favorites': payload.favorites,
      'watch_progress': payload.watchProgress,
      'views': payload.views,
    });
  }
}
