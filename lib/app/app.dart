import 'dart:ui';

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
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      canvasColor: AppPalette.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.white10,
      scaffoldBackgroundColor: AppPalette.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppPalette.accent,
        secondary: AppPalette.accent,
        surface: AppPalette.bg,
        onSurface: AppPalette.text,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughBuilder(),
          TargetPlatform.iOS: _FadeThroughBuilder(),
          TargetPlatform.macOS: _FadeThroughBuilder(),
          TargetPlatform.linux: _FadeThroughBuilder(),
          TargetPlatform.windows: _FadeThroughBuilder(),
        },
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppPalette.text),
        titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: AppPalette.text),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: AppPalette.text),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppPalette.text,
        unselectedLabelColor: AppPalette.textDim2,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
        indicatorColor: AppPalette.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppPalette.accent, width: 1.4),
        ),
        hintStyle: const TextStyle(color: AppPalette.textDim2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surfaceHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppPalette.accent,
        thumbColor: Colors.white,
        inactiveTrackColor: AppPalette.field,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.field,
        selectedColor: AppPalette.field,
        labelStyle: const TextStyle(fontSize: 12.5),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppPalette.textDim,
        titleTextStyle: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500, color: AppPalette.text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.textDim),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.accent,
        foregroundColor: Colors.black,
      ),
    );
  }
}

/// Fade + slight zoom page transition instead of the default Material zoom.
class _FadeThroughBuilder extends PageTransitionsBuilder {
  const _FadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.03, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}

/// Tab container with adaptive, fully custom chrome:
/// translucent icon rail on TV/tablet/desktop, glass bottom bar on phones.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static final _tabs = <String, WidgetBuilder>{
    'Home': (c) => const HomeTab(),
    'Live TV': (c) => const LiveScreen(),
    'Guide': (c) => const GuideScreen(),
    'Filme & Serien': (c) => const VodScreen(),
    'Suche': (c) => const SearchScreen(),
    'Einstellungen': (c) => const SettingsScreen(),
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
    final width = MediaQuery.of(context).size.width;
    final entries = _tabs.entries.toList();

    final body = IndexedStack(
      index: _index,
      children: [
        for (final e in entries)
          Builder(key: ValueKey(e.key), builder: e.value),
      ],
    );

    if (width < 900) {
      return Scaffold(
        body: body,
        bottomNavigationBar: _GlassBar(
          items: _tabs.keys.toList(),
          index: _index,
          onSelect: (i) => setState(() => _index = i),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _SideRail(
            items: _tabs.keys.toList(),
            index: _index,
            onSelect: (i) => setState(() => _index = i),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final bool selected;

  const _NavItem(this.label, this.icon, {required this.selected});
}

class _GlassBar extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onSelect;

  const _GlassBar({
    required this.items,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          color: AppPalette.navBg,
          padding: EdgeInsets.only(bottom: safe.bottom, top: 4),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _BarItem(
                    item:
                        _NavItem(items[i], _iconFor(items[i]), selected: i == index),
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final _NavItem item;
  final VoidCallback onTap;

  const _BarItem({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = item.selected ? AppPalette.text : AppPalette.textDim2;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Icon(item.icon, size: 23, color: ink),
              if (item.selected)
                Positioned(
                  bottom: -7,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppPalette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: item.selected ? FontWeight.w600 : FontWeight.w400,
              color: ink,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onSelect;

  const _SideRail({
    required this.items,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final extended = MediaQuery.of(context).size.width >= 1200;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: extended ? 208 : 78,
          color: AppPalette.navBg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(extended ? 18 : 19, 22, 16, 18),
                child: _LogoMark(compact: !extended),
              ),
              for (var i = 0; i < items.length; i++)
                _RailItem(
                  item:
                      _NavItem(items[i], _iconFor(items[i]), selected: i == index),
                  extended: extended,
                  onTap: () => onSelect(i),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final _NavItem item;
  final bool extended;
  final VoidCallback onTap;

  const _RailItem({
    required this.item,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = item.selected ? AppPalette.text : AppPalette.textDim2;
    final content = Row(
      children: [
        Icon(item.icon, size: 22, color: ink),
        if (extended) ...[
          const SizedBox(width: 14),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: item.selected ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: -0.1,
              color: ink,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: SizedBox(
        height: 44,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: item.selected
                      ? Colors.white.withValues(alpha: 0.07)
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                child: content,
              ),
              if (item.selected)
                Positioned(
                  left: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppPalette.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final bool compact;
  const _LogoMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppPalette.accent,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: AppPalette.accent.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child:
          const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 27),
    );
    if (compact) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 11),
        const Text(
          'IPTV',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppPalette.text,
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(String label) {
  switch (label) {
    case 'Home':
      return Icons.space_dashboard_outlined;
    case 'Live TV':
      return Icons.live_tv_outlined;
    case 'Guide':
      return Icons.calendar_view_week_outlined;
    case 'Filme & Serien':
      return Icons.movie_outlined;
    case 'Suche':
      return Icons.search_outlined;
    default:
      return Icons.settings_outlined;
  }
}
