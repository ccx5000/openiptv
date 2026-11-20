class AppConfig {
  /// Backend selection: 'rest' (self-hosted docker compose, default) or
  /// 'supabase' (Supabase cloud project).
  static const String backendMode = String.fromEnvironment(
    'BACKEND',
    defaultValue: 'rest',
  );

  /// REST backend base URL — für andere Geräte die LAN-/Server-IP verwenden,
  /// z. B. http://192.168.1.50:8080.
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  /// Supabase cloud (nur wenn BACKEND=supabase).
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-ANON-KEY',
  );
}
