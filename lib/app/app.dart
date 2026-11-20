import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/library_controller.dart';
import 'widgets.dart';
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
      home: const ProfileGate(),
    );
  }

  ThemeData _dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppPalette.accent,
        secondary: AppPalette.accent2,
        surface: AppPalette.surface,
        onSurface: AppPalette.text,
        surfaceContainerHighest: AppPalette.surfaceHi,
      ),
      scaffoldBackgroundColor: AppPalette.bg,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppPalette.text,
        unselectedLabelColor: AppPalette.textDim2,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.navBg,
        indicatorColor: AppPalette.accent.withOpacity(0.22),
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? AppPalette.text
                  : AppPalette.textDim,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppPalette.accent
                  : AppPalette.textDim,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.accent, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surfaceHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surfaceHi,
        modalBackgroundColor: AppPalette.surfaceHi,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.surfaceHi,
        contentTextStyle: const TextStyle(color: AppPalette.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppPalette.accent,
        thumbColor: AppPalette.accent,
        inactiveTrackColor: AppPalette.field,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surface,
        selectedColor: AppPalette.accent.withOpacity(0.25),
        labelStyle: const TextStyle(fontSize: 12.5),
        side: BorderSide(color: Colors.white.withOpacity(0.07)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.06),
        thickness: 1,
      ),
    );

    return base.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.accent),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(focusColor: AppPalette.accent.withOpacity(0.3)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.navBg,
        indicatorColor: AppPalette.accent.withOpacity(0.22),
        selectedIconTheme: const IconThemeData(color: AppPalette.accent),
        unselectedIconTheme: const IconThemeData(color: AppPalette.textDim),
        selectedLabelTextStyle: const TextStyle(
            color: AppPalette.text, fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelTextStyle: const TextStyle(
            color: AppPalette.textDim, fontSize: 12),
      ),
    );
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

  static final _tabs = <String, WidgetBuilder>{
    'Home': (c) => HomeTab(),
    'Live TV': (c) => LiveScreen(),
    'Guide': (c) => GuideScreen(),
    'Filme & Serien': (c) => VodScreen(),
    'Suche': (c) => SearchScreen(),
    'Einstellungen': (c) => SettingsScreen(),
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
                selectedIcon: Icon(_iconFor(e.key, active: true)),
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
            leading: Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 10),
              child: _LogoMark(compact: true),
            ),
            destinations: [
              for (final e in entries)
                NavigationRailDestination(
                  icon: Icon(_iconFor(e.key)),
                  selectedIcon: Icon(_iconFor(e.key, active: true)),
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

  IconData _iconFor(String label, {bool active = false}) {
    switch (label) {
      case 'Home':
        return active
            ? Icons.space_dashboard_rounded
            : Icons.space_dashboard_outlined;
      case 'Live TV':
        return active ? Icons.live_tv_rounded : Icons.live_tv_outlined;
      case 'Guide':
        return active
            ? Icons.calendar_view_week_rounded
            : Icons.calendar_view_week_outlined;
      case 'Filme & Serien':
        return active ? Icons.movie_rounded : Icons.movie_outlined;
      case 'Suche':
        return active ? Icons.search_rounded : Icons.search_outlined;
      default:
        return active
            ? Icons.settings_rounded
            : Icons.settings_outlined;
    }
  }
}

class _LogoMark extends StatelessWidget {
  final bool compact;
  const _LogoMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppPalette.accentGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppPalette.accent.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
    );
  }
}
