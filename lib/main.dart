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



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
  if (loggedInUserId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first')),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SearchForm(userId: loggedInUserId!),
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

                        // close login screen + chooser screen
                        Navigator.pop(context); // close login
                        Navigator.pop(context); // close chooser

                        await _loadSession(); // refresh menu username
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
      onSearch: _openSearch,                     // 👈 use Navigator
      onAddLink: _openAddLink,
      onSignUpOrLogin: _openSignUpOrLogin,
      onLogout: isLoggedIn ? logout : null,
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
  final Future<void> Function()? onLogout;

  const MenuForm({
    super.key,
    required this.isLoggedIn,
    required this.username,
    required this.onSearch,
    required this.onAddLink,
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