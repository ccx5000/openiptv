import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/library_controller.dart';
import '../core/services/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/home/home_screen.dart';
import '../features/live/live_screen.dart';
import '../features/profiles/profile_gate.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/vod/vod_screen.dart';

class OpenIptvApp extends StatelessWidget {
  const OpenIptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenIPTV',
      debugShowCheckedModeBanner: false,
      theme: _dark(),
      home: const AuthGate(),
    );
  }

  ThemeData _dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B0E14),
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF4F8CFF),
        secondary: const Color(0xFF8C6CFF),
        surface: const Color(0xFF131722),
        onSurface: const Color(0xFFE6EAF2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF131722),
        indicatorColor: const Color(0xFF4F8CFF),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, color: Color(0xFFE6EAF2)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B2130),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Auth gate: shows login until a Supabase session exists, then the
/// profile picker, then the app shell.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    context.read<AuthService>().init();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.signedIn) return const LoginScreen();
    return const ProfileGate();
  }
}

/// Tab container with adaptive navigation:
/// bottom bar on phones, navigation rail on TV/tablet/desktop.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = <String, WidgetBuilder>{
    'Home': HomeTab.new,
    'Live TV': LiveScreen.new,
    'Guide': GuideScreen.new,
    'Filme & Serien': VodScreen.new,
    'Suche': SearchScreen.new,
    'Einstellungen': SettingsScreen.new,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryController>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final entries = _tabs.entries.toList();

    final body = IndexedStack(
      index: _index,
      children: [for (final e in entries) Builder(key: ValueKey(e.key), builder: e.value)],
    );

    if (!wide) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final e in entries)
              NavigationDestination(
                icon: Icon(_iconFor(e.key)),
                label: e.key,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            extended: MediaQuery.of(context).size.width >= 1200,
            minExtendedWidth: 220,
            backgroundColor: const Color(0xFF131722),
            destinations: [
              for (final e in entries)
                NavigationRailDestination(
                  icon: Icon(_iconFor(e.key)),
                  label: Text(e.key),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  IconData _iconFor(String label) => switch (label) {
        'Home' => Icons.home_rounded,
        'Live TV' => Icons.live_tv_rounded,
        'Guide' => Icons.calendar_view_week_rounded,
        'Filme & Serien' => Icons.movie_rounded,
        'Suche' => Icons.search_rounded,
        _ => Icons.settings_rounded,
      };
}
