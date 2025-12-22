import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'SignUpForm.dart';
import 'LogInForm.dart';
import 'verifyEmailForm.dart';
import 'searchForm.dart';
import 'addLinkForm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.load();
  runApp(MyApp(themeController: themeController));
}

class MyApp extends StatelessWidget {
  final ThemeController themeController;
  const MyApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'links Demo',
          theme: themeController.theme,
          home: HomePage(themeController: themeController),
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final ThemeController themeController;
  const HomePage({super.key, required this.themeController});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? userEmail;
  int? loggedInUserId;
  String? loggedInEmail;
  String? loggedInUsername;
  bool _sessionLoaded = false;

  bool get isLoggedIn => loggedInUserId != null;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _openAddLink() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLinkForm(
          loggedInUserId: loggedInUserId,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchForm(userId: loggedInUserId),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(controller: widget.themeController),
      ),
    );
  }

  void _openSignUpOrLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpOrLoginForm(
          onBack: () => Navigator.pop(context),
          onLogin: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Log in')),
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: LoginForm(
                        onLoginSuccess: (userId, email, username) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('user_id', userId);
                          await prefs.setString('email', email);
                          await prefs.setString('username', username);

                          Navigator.pop(context); // close login
                          Navigator.pop(context); // close chooser

                          await _loadSession();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          onSignup: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Sign up')),
                  body: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SingleChildScrollView(
                      child: SignupForm(
                        onSignupSuccess: (email) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VerifyEmailForm(
                                email: email,
                                onBack: () => Navigator.pop(context),
                                onVerified: () {
                                  Navigator.pop(context); // close verify
                                  Navigator.pop(context); // close signup
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final email = prefs.getString('email');
    final username = prefs.getString('username');

    setState(() {
      if (userId != null && email != null && username != null) {
        loggedInUserId = userId;
        loggedInEmail = email;
        loggedInUsername = username;
      }
      _sessionLoaded = true;
    });
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('user_id');
    await prefs.remove('email');
    await prefs.remove('username');

    setState(() {
      loggedInUserId = null;
      loggedInEmail = null;
      loggedInUsername = null;
      Navigator.popUntil(context, (route) => route.isFirst);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MenuForm(
      isLoggedIn: isLoggedIn,
      username: loggedInUsername,
      onSearch: _openSearch,
      onAddLink: _openAddLink,
      onSignUpOrLogin: _openSignUpOrLogin,
      onSettings: _openSettings,
      onLogout: isLoggedIn ? logout : null,
      themeController: widget.themeController,
    );
  }
}

/// ---------------- MENU FORM ----------------

class MenuForm extends StatelessWidget {
  final bool isLoggedIn;
  final String? username;
  final VoidCallback onSearch;
  final VoidCallback onAddLink;
  final VoidCallback onSignUpOrLogin;
  final VoidCallback onSettings;
  final Future<void> Function()? onLogout;
  final ThemeController themeController;

  const MenuForm({
    super.key,
    required this.isLoggedIn,
    required this.username,
    required this.onSearch,
    required this.onAddLink,
    required this.onSignUpOrLogin,
    required this.onSettings,
    required this.themeController,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final spec = themeController.spec;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLoggedIn ? 'Hello, $username' : 'Choose an option'),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: spec.background),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _MenuButton(
                icon: Icons.search,
                label: 'Search',
                onTap: onSearch,
                themeController: themeController,
              ),
              _MenuButton(
                icon: Icons.group_add,
                label: 'Add Link',
                onTap: onAddLink,
                themeController: themeController,
              ),
              _MenuButton(
                icon: Icons.person_add,
                label: 'Sign Up or Log In',
                onTap: onSignUpOrLogin,
                themeController: themeController,
              ),
              _MenuButton(
                icon: Icons.settings,
                label: 'Settings',
                onTap: onSettings,
                themeController: themeController,
              ),
              if (isLoggedIn && onLogout != null)
                _MenuButton(
                  icon: Icons.logout,
                  label: 'Log Out',
                  onTap: () => onLogout!(),
                  themeController: themeController,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- SIGN UP OR LOGIN FORM ----------------

class SignUpOrLoginForm extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const SignUpOrLoginForm({
    super.key,
    required this.onBack,
    required this.onLogin,
    required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose an option'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _MenuButton(
              icon: Icons.account_circle,
              label: 'log in',
              onTap: onLogin,
              themeController: ThemeController.preview(AppThemeId.futuristic),
            ),
            _MenuButton(
              icon: Icons.group_add,
              label: 'sign up',
              onTap: onSignup,
              themeController: ThemeController.preview(AppThemeId.futuristic),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------- SETTINGS SCREEN ----------------

class SettingsScreen extends StatelessWidget {
  final ThemeController controller;
  const SettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.themeId;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your design',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: AppThemeId.values.map((id) {
                      final spec = AppThemes.spec(id);
                      final selected = id == current;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => controller.setTheme(id),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: spec.tile,
                              border: Border.all(
                                color: selected ? spec.tileGlow : spec.tileBorder,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: spec.tileGlow.withOpacity(selected ? 0.28 : 0.12),
                                  blurRadius: selected ? 22 : 14,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: spec.background,
                                    border: Border.all(color: spec.tileBorder),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    spec.displayName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: spec.onTile,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Icon(Icons.check_circle, color: spec.tileGlow),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ---------------- MENU BUTTON ----------------

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeController themeController;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.themeController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final spec = themeController.spec;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: spec.tile,
          border: Border.all(color: spec.tileBorder),
          boxShadow: [
            BoxShadow(
              color: spec.tileGlow.withOpacity(0.20),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 38, color: spec.onTile),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: spec.onTile,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- THEMES + CONTROLLER ----------------

enum AppThemeId { futuristic, california, magical, cyberDark, minimalLight }

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'app_theme';

  AppThemeId _themeId = AppThemeId.futuristic;
  AppThemeId get themeId => _themeId;

  ThemeData get theme => AppThemes.themeData(_themeId);
  ThemeSpec get spec => AppThemes.spec(_themeId);

  ThemeController();

  /// For screens where you don't pass controller (optional).
  /// This creates a non-persistent preview controller.
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
