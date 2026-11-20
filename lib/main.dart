import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/backend/backend.dart';
import 'core/backend/local_backend.dart';
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

  // Offline first: the app works without any account. Sync (optional) is
  // enabled later in Settings and survives restarts via restoreSync().
  final local = LocalBackend(db);
  final BackendRouter backend = BackendRouter(local);
  await backend.init();

  final auth = AuthService(backend, settings, local);
  final sync = SyncService(db, backend);
  final library = LibraryController(db, settings, sync);
  if (AppConfig.backendMode == 'supabase') {
    await backend.use(SupabaseBackend());
  } else {
    await auth.restoreSync();
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<SettingsService>.value(value: settings),
        Provider<BackendRouter>.value(value: backend),
        Provider<Backend>.value(value: backend),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        Provider<SyncService>.value(value: sync),
        ChangeNotifierProvider<LibraryController>.value(value: library),
      ],
      child: const OpenIptvApp(),
    ),
  );
}
