import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Config.dart';

enum AppThemeId { futuristic, california, magical, cyberDark, minimalLight }

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'app_theme';

  AppThemeId _themeId = AppThemeId.futuristic;
  AppThemeId get themeId => _themeId;

  ThemeData get theme => AppThemes.themeData(_themeId);
  ThemeSpec get spec => AppThemes.spec(_themeId);

  ThemeController();

  factory ThemeController.preview(AppThemeId id) {
    final c = ThemeController();
    c._themeId = id;
    return c;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      _themeId = AppThemeId.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AppThemeId.futuristic,
      );
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemeId id) async {
    _themeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, id.name);
  }
}

class ThemeSpec {
  final String displayName;
  final Gradient background;
  final Gradient tile;
  final Color tileBorder;
  final Color tileGlow;
  final Color onTile;

  const ThemeSpec({
    required this.displayName,
    required this.background,
    required this.tile,
    required this.tileBorder,
    required this.tileGlow,
    required this.onTile,
  });
}

class AppThemes {
  static InputDecorationTheme _inputTheme({
    required Color focus,
    required Color border,
    required Color fill,
    required Color hint,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(color: hint),
      labelStyle: TextStyle(color: hint),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: focus, width: 2.0),
      ),
    );
  }

  static ThemeData themeData(AppThemeId id) {
    switch (id) {
      case AppThemeId.futuristic:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF070A12),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E5FF),
            secondary: Color(0xFFB400FF),
            surface: Color(0xFF0B1020),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF070A12),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF101A33),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: _inputTheme(
            focus: const Color(0xFF00E5FF),
            border: const Color(0xFF243258),
            fill: const Color(0xFF0B1020),
            hint: const Color(0xFF9FB3FF),
          ),
          useMaterial3: true,
        );

      case AppThemeId.california:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFF6EF),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFFF5A5F),
            secondary: Color(0xFFFFB703),
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFFF6EF),
            foregroundColor: Color(0xFF231F20),
            elevation: 0,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF231F20),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: _inputTheme(
            focus: const Color(0xFFFF5A5F),
            border: const Color(0xFFE6C7B6),
            fill: Colors.white,
            hint: const Color(0xFF7B6F6A),
          ),
          useMaterial3: true,
        );

      case AppThemeId.magical:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0B0712),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF9D4EDD),
            secondary: Color(0xFF4CC9F0),
            surface: Color(0xFF140B22),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B0712),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF1A1030),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: _inputTheme(
            focus: const Color(0xFF4CC9F0),
            border: const Color(0xFF3B2A5A),
            fill: const Color(0xFF140B22),
            hint: const Color(0xFFBFA7FF),
          ),
          useMaterial3: true,
        );

      case AppThemeId.cyberDark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF050505),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00FF87),
            secondary: Color(0xFFFF2A6D),
            surface: Color(0xFF0C0C0C),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF050505),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF121212),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: _inputTheme(
            focus: const Color(0xFF00FF87),
            border: const Color(0xFF2B2B2B),
            fill: const Color(0xFF0C0C0C),
            hint: const Color(0xFF8A8A8A),
          ),
          useMaterial3: true,
        );

      case AppThemeId.minimalLight:
        return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF7F7F9),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF111827),
            secondary: Color(0xFF2563EB),
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F7F9),
            foregroundColor: Color(0xFF111827),
            elevation: 0,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF111827),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
          inputDecorationTheme: _inputTheme(
            focus: const Color(0xFF2563EB),
            border: const Color(0xFFD1D5DB),
            fill: Colors.white,
            hint: const Color(0xFF6B7280),
          ),
          useMaterial3: true,
        );
    }
  }

  static ThemeSpec spec(AppThemeId id) {
    switch (id) {
      case AppThemeId.futuristic:
        return const ThemeSpec(
          displayName: "Futuristic Neon",
          background: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070A12), Color(0xFF0B1020), Color(0xFF0A1A2E)],
          ),
          tile: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1020), Color(0xFF111B35)],
          ),
          tileBorder: Color(0xFF243258),
          tileGlow: Color(0xFF00E5FF),
          onTile: Colors.white,
        );

      case AppThemeId.california:
        return const ThemeSpec(
          displayName: "California Sunset",
          background: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF6EF), Color(0xFFFFE1C7), Color(0xFFFFD166)],
          ),
          tile: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFFF1E7)],
          ),
          tileBorder: Color(0xFFE6C7B6),
          tileGlow: Color(0xFFFF5A5F),
          onTile: Color(0xFF231F20),
        );

      case AppThemeId.magical:
        return const ThemeSpec(
          displayName: "Magical Aura",
          background: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0712), Color(0xFF140B22), Color(0xFF201040)],
          ),
          tile: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF140B22), Color(0xFF1A1030)],
          ),
          tileBorder: Color(0xFF3B2A5A),
          tileGlow: Color(0xFF4CC9F0),
          onTile: Colors.white,
        );

      case AppThemeId.cyberDark:
        return const ThemeSpec(
          displayName: "Cyberpunk Dark",
          background: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050505), Color(0xFF0C0C0C), Color(0xFF101015)],
          ),
          tile: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C0C0C), Color(0xFF141414)],
          ),
          tileBorder: Color(0xFF2B2B2B),
          tileGlow: Color(0xFF00FF87),
          onTile: Colors.white,
        );

      case AppThemeId.minimalLight:
        return const ThemeSpec(
          displayName: "Minimal Clean",
          background: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F7F9), Color(0xFFF1F5F9), Color(0xFFEFF6FF)],
          ),
          tile: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFC)],
          ),
          tileBorder: Color(0xFFD1D5DB),
          tileGlow: Color(0xFF2563EB),
          onTile: Color(0xFF111827),
        );
    }
  }
}