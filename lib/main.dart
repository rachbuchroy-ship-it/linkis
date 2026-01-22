import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linkis/theme_controller.dart';

import 'SignUpForm.dart';
import 'LogInForm.dart';
import 'verifyEmailForm.dart';
import 'searchForm.dart';
import 'addLinkForm.dart';
import 'settings_screen.dart';
import 'my_links_screen.dart'; 

import 'Config.dart';

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

  int _currentIndex = 0;

  bool get isLoggedIn => loggedInUserId != null;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  void _openLogin() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
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

                  Navigator.pop(context); // close login screen
                  await _loadSession();

                  // optional: go to My Links after login
                  setState(() {
                    _currentIndex = isLoggedIn ? 2 : 0;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _openSignup() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
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
                      builder: (_) => VerifyEmailForm(
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
}

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(controller: widget.themeController),
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
        if (_currentIndex == 2) _currentIndex = 0; // if was on My Links
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
      _currentIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final spec = widget.themeController.spec;

    // Build pages list (My Links only if logged in)
    final pages = <Widget>[
      SearchForm(userId: loggedInUserId),
      AddLinkForm(loggedInUserId: loggedInUserId),
      if (isLoggedIn)
        MyLinksScreen(
          userId: loggedInUserId!,
          themeController: widget.themeController,
        ),
      // Profile-like tab: login/logout
      _AccountTab(
        isLoggedIn: isLoggedIn,
        username: loggedInUsername,
        onOpenLogin: _openLogin,
        onOpenSignup: _openSignup,
        onLogout: logout,
        onSettings: _openSettings,
        themeController: widget.themeController,
      ),
    ];

    // Build nav items aligned with pages
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
      const BottomNavigationBarItem(icon: Icon(Icons.add_link), label: 'Add'),
      if (isLoggedIn)
        const BottomNavigationBarItem(
          icon: Icon(Icons.bookmark),
          label: 'My Links',
        ),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Account'),
    ];

    // If user logged out and My Links tab vanished, keep index safe
    final maxIndex = items.length - 1;
    if (_currentIndex > maxIndex) _currentIndex = maxIndex;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: spec.background),
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: items, // ✅ REQUIRED
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
class _AccountTab extends StatelessWidget {
  final bool isLoggedIn;
  final String? username;

  final VoidCallback onOpenLogin;
  final VoidCallback onOpenSignup;

  final Future<void> Function() onLogout;
  final VoidCallback onSettings;
  final ThemeController themeController;

  const _AccountTab({
    required this.isLoggedIn,
    required this.username,
    required this.onOpenLogin,
    required this.onOpenSignup,
    required this.onLogout,
    required this.onSettings,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final spec = themeController.spec;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.all(16),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 48, color: spec.onTile),
            const SizedBox(height: 10),
            Text(
              isLoggedIn ? 'Logged in as $username' : 'Account',
              style: TextStyle(
                color: spec.onTile,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            if (!isLoggedIn) ...[
              SizedBox(
                child: TextButton(
                  onPressed: onOpenLogin,
                  child: const Text('Log in'),
                ),
              ),
              
              const SizedBox(height: 10),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onOpenSignup,
                child: const Text('Sign up'),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onLogout(),
                  child: const Text('Log out'),
                ),
              ),
            ],

            const SizedBox(height: 10),
            TextButton(
              onPressed: onSettings,
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}



