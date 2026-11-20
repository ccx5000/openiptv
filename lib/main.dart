import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/backend/backend.dart';
import 'core/backend/rest_backend.dart';
import 'core/backend/supabase_backend.dart';
import 'core/config.dart';
import 'core/database/database.dart';
import 'core/library_controller.dart';
import 'core/services/auth_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final db = AppDatabase();
  final settings = SettingsService(db);

  final Backend backend = AppConfig.backendMode == 'supabase'
      ? SupabaseBackend()
      : RestBackend(AppConfig.backendUrl);
  await backend.init();

  final auth = AuthService(backend);
  final sync = SyncService(db, backend);
  final library = LibraryController(db, settings, sync);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<SettingsService>.value(value: settings),
        Provider<Backend>.value(value: backend),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        Provider<SyncService>.value(value: sync),
        ChangeNotifierProvider<LibraryController>.value(value: library),
      ],
      child: const OpenIptvApp(),
    ),
  );
}
