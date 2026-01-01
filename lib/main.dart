import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linkis/theme_controller.dart';

import 'SignUpForm.dart';
import 'LogInForm.dart';
import 'verifyEmailForm.dart';
import 'searchForm.dart';
import 'addLinkForm.dart';
import 'settings_screen.dart';
import 'my_links_screen.dart'; // <-- NEW

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

  // ---------- NEW: OPEN MY LINKS ----------
  void _openMyLinks() {
    if (loggedInUserId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyLinksScreen(
          userId: loggedInUserId!,
          themeController: widget.themeController,
        ),
      ),
    );
  }

  void _openSignUpOrLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignUpOrLoginForm(
          themeController: widget.themeController,
          onBack: () => Navigator.pop(context),
          onLogin: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Log in')),
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: widget.themeController.spec.background,
                    ),
                    child: Padding(
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
              ),
            );
          },
          onSignup: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Sign up')),
                  body: Container(
                    decoration: BoxDecoration(
                      gradient: widget.themeController.spec.background,
                    ),
                    child: Padding(
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
      } else {
        loggedInUserId = null;
        loggedInEmail = null;
        loggedInUsername = null;
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
    });

    Navigator.popUntil(context, (route) => route.isFirst);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MenuForm(
      isLoggedIn: isLoggedIn,
      userId: loggedInUserId, // <-- NEW
      username: loggedInUsername,
      onSearch: _openSearch,
      onAddLink: _openAddLink,
      onMyLinks: _openMyLinks, // <-- NEW
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
  final int? userId; // <-- NEW
  final String? username;

  final VoidCallback onSearch;
  final VoidCallback onAddLink;
  final VoidCallback onMyLinks; // <-- NEW
  final VoidCallback onSignUpOrLogin;
  final VoidCallback onSettings;
  final Future<void> Function()? onLogout;
  final ThemeController themeController;

  const MenuForm({
    super.key,
    required this.isLoggedIn,
    required this.userId,
    required this.username,
    required this.onSearch,
    required this.onAddLink,
    required this.onMyLinks,
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

              // ---------- NEW: MY LINKS TILE (ONLY IF LOGGED IN) ----------
              if (userId != null)
                _MenuButton(
                  icon: Icons.bookmark,
                  label: 'My Links',
                  onTap: onMyLinks,
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
  final ThemeController themeController;
  final VoidCallback onBack;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  const SignUpOrLoginForm({
    super.key,
    required this.themeController,
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
      body: Container(
        decoration: BoxDecoration(gradient: themeController.spec.background),
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
              themeController: themeController,
            ),
            _MenuButton(
              icon: Icons.group_add,
              label: 'sign up',
              onTap: onSignup,
              themeController: themeController,
            ),
          ],
        ),
      ),
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

