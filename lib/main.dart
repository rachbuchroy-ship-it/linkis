import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'SignUpForm.dart';
import 'LogInForm.dart';
import 'verifyEmailForm.dart';
import 'searchForm.dart';
import 'addLinkForm.dart';
import 'categoriesForm.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'links Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

enum AppView {
  menu,
  search,
  add,
  categories,
  signup,
  verifyEmail,
  logIn,
  signUpOrLogin,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppView currentView = AppView.menu;
  String? userEmail;
  int? loggedInUserId;
  String? loggedInEmail;
  String? loggedInUsername;
  bool _sessionLoaded = false; // just informational

  bool get isLoggedIn => loggedInUserId != null;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final email = prefs.getString('email');
    final username = prefs.getString('username');

    print('LOADED FROM PREFS: userId=$userId, email=$email, username=$username');

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
      currentView = AppView.menu;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  void goTo(AppView view) {
    setState(() {
      currentView = view;
    });
  }

  String _titleFor(AppView v) {
    switch (v) {
      case AppView.add:
        return 'Add Link';
      case AppView.categories:
        return 'Categories';
      case AppView.signup:
        return 'Sign Up';
      case AppView.search:
        return 'Search';
      default:
        return 'Menu';
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (currentView) {
      // -------------- MENU ----------------
      case AppView.menu:
        return MenuForm(
          isLoggedIn: isLoggedIn,
          username: loggedInUsername,
          onSearch: () => goTo(AppView.search),
          onAddLink: () => goTo(AppView.add),
          onCategories: () => goTo(AppView.categories),
          onSignUpOrLogin: () => goTo(AppView.signUpOrLogin),
          onLogout: isLoggedIn ? logout : null,
        );

      // -------------- SIGN UP OR LOGIN CHOOSER ----------------
      case AppView.signUpOrLogin:
        return SignUpOrLoginForm(
          onBack: () => goTo(AppView.menu),
          onLogin: () => goTo(AppView.logIn),
          onSignup: () => goTo(AppView.signup),
        );

      // -------------- SEARCH ----------------
      case AppView.search:
        return SearchForm(
          onBack: () => goTo(AppView.menu),
        );

      // -------------- ADD LINK ----------------
      case AppView.add:
        return AddLinkForm(
          title: _titleFor(currentView),
          loggedInUserId: loggedInUserId,
          onBack: () => goTo(AppView.menu),
        );

      // -------------- CATEGORIES ----------------
      case AppView.categories:
        return CategoriesForm(
          title: _titleFor(currentView),
          onBack: () => goTo(AppView.menu),
        );

      // -------------- LOG IN ----------------
      case AppView.logIn:
        return Scaffold(
          appBar: AppBar(
            title: const Text('Log in'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => goTo(AppView.menu),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: LoginForm(
                onLoginSuccess: (userId, email, username) async {
                  print('LOGIN SUCCESS: userId=$userId, email=$email, username=$username');

                  final prefs = await SharedPreferences.getInstance();
                  final ok1 = await prefs.setInt('user_id', userId);
                  final ok2 = await prefs.setString('email', email);
                  final ok3 = await prefs.setString('username', username);
                  print('PREFS SAVED: userId=$ok1, email=$ok2, username=$ok3');

                  setState(() {
                    loggedInUserId = userId;
                    loggedInEmail = email;
                    loggedInUsername = username;
                  });

                  goTo(AppView.menu);
                },
              ),
            ),
          ),
        );

      // -------------- SIGN UP ----------------
      case AppView.signup:
        return Scaffold(
          appBar: AppBar(
            title: Text(_titleFor(currentView)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => goTo(AppView.menu),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: SignupForm(
                onSignupSuccess: (email) {
                  setState(() {
                    userEmail = email;
                  });
                  goTo(AppView.verifyEmail);
                },
              ),
            ),
          ),
        );

      // -------------- VERIFY EMAIL ----------------
      case AppView.verifyEmail:
        return VerifyEmailForm(
          email: userEmail ?? 'unknown@email.com',
          onBack: () => goTo(AppView.menu),
          onVerified: () => goTo(AppView.logIn),
        );
    }
  }
}

/// ---------------- MENU FORM ----------------

class MenuForm extends StatelessWidget {
  final bool isLoggedIn;
  final String? username;
  final VoidCallback onSearch;
  final VoidCallback onAddLink;
  final VoidCallback onCategories;
  final VoidCallback onSignUpOrLogin;
  final Future<void> Function()? onLogout;

  const MenuForm({
    super.key,
    required this.isLoggedIn,
    required this.username,
    required this.onSearch,
    required this.onAddLink,
    required this.onCategories,
    required this.onSignUpOrLogin,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    print('isLoggedIn=$isLoggedIn, loggedInUsername=$username');
    return Scaffold(
      appBar: AppBar(
        title: Text(isLoggedIn ? 'Hello, $username' : 'Choose an option'),
      ),
      body: Padding(
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
            ),
            _MenuButton(
              icon: Icons.group_add,
              label: 'Add Link',
              onTap: onAddLink,
            ),
            _MenuButton(
              icon: Icons.category,
              label: 'Categories',
              onTap: onCategories,
            ),
            _MenuButton(
              icon: Icons.person_add,
              label: 'Sign Up or Log In',
              onTap: onSignUpOrLogin,
            ),
            if (isLoggedIn && onLogout != null)
              _MenuButton(
                icon: Icons.logout,
                label: 'Log Out',
                onTap: () {
                  onLogout!();
                },
              ),
          ],
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
            ),
            _MenuButton(
              icon: Icons.group_add,
              label: 'sign up',
              onTap: onSignup,
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

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36),
              const SizedBox(height: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}