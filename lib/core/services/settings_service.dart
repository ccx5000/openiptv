import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../database/database.dart';

/// Small key/value settings on top of the local DB plus a secure
/// credential store for IPTV server logins (never synced, never logged).
class SettingsService {
  final AppDatabase db;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  SettingsService(this.db);

  Future<String?> get(String key) => db.meta(key);

  Future<void> set(String key, String value) => db.setMeta(key, value);

  // ---- Parental control -------------------------------------------------
  static const _pinKey = 'parental_pin_sha256';

  Future<void> setParentalPin(String pin) async =>
      await set(_pinKey, _hash(pin));

  Future<bool> hasParentalPin() async => (await get(_pinKey)) != null;

  Future<bool> checkParentalPin(String pin) async =>
      (await get(_pinKey)) == _hash(pin);

  Future<void> clearParentalPin() async => await set(_pinKey, '');

  // ---- Playlist credentials --------------------------------------------
  Future<void> saveCredentials(
      String playlistId, String user, String pass) async {
    await _secure.write(
        key: 'cred:$playlistId', value: jsonEncode({'u': user, 'p': pass}));
  }

  Future<Credentials?> credentials(String playlistId) async {
    final raw = await _secure.read(key: 'cred:$playlistId');
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Credentials(j['u'].toString(), j['p'].toString());
  }

  Future<void> deleteCredentials(String playlistId) =>
      _secure.delete(key: 'cred:$playlistId');

  String _hash(String input) =>
      crypto.sha256.convert(utf8.encode(input)).toString();
}

class Credentials {
  final String user;
  final String pass;
  const Credentials(this.user, this.pass);
}
