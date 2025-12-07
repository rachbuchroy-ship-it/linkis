import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
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
  Timer? _debounce;
  // password strength
  double _passwordStrength = 0.0; // 0.0 – 1.0
  String _passwordLabel = 'Too weak';

  // search state
  List<LinkItem> items = []; // שינוי מ-List<String> ל-List<LinkItem>
  String query = "";
  bool isLoading = false;

  // controllers (now initialized in initState)
  late final TextEditingController _addController;
  late final TextEditingController usernameController;
  late final TextEditingController passwordController;
  late final TextEditingController emailController;

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

Future<Map<String, dynamic>> verifyEmailCode(String email, String code) async {
  final url = Uri.parse('http://127.0.0.1:5000/verify');
  // For Android emulator use: http://10.0.2.2:5000/verify

  try {
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
      }),
    );

    final body = jsonDecode(res.body);
    print('VERIFY RESPONSE: status=${res.statusCode}, body=$body');

    return {
      'success': body['success'] == true,
      'statusCode': res.statusCode,
      'message': body['message'] ?? 'Unknown response',
    };
  } catch (e) {
    print('VERIFY ERROR: $e');
    return {
      'success': false,
      'statusCode': 0,
      'message': 'Error sending request: $e',
    };
  }
}
  @override
  void initState() {
    super.initState();
    _addController = TextEditingController();
    usernameController = TextEditingController();
    passwordController = TextEditingController();
    emailController = TextEditingController();
  }

  @override
@override
void dispose() {
  // ניקוי הבקר של הוספת הקישור (מוגדר ב-HomePageState)
  _addController.dispose();

  // ניקוי הטיימר של ה-Debounce (הוספה חובה כאן)
  _debounce?.cancel();   
  super.dispose();
}

Future<void> fetchItems() async {
    setState(() => isLoading = true);
    try {
      final uri = Uri.parse('http://127.0.0.1:5000/links').replace(
        queryParameters: {
          'q': query,
          // בעתיד: 'user_id': user_id,
        },
      );
      
      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          // קליטת האובייקטים המלאים והמרתם למודל LinkItem
          items = data.map((e) => LinkItem.fromJson(e as Map<String, dynamic>)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load links: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading links: $e')),
      );
    }
  }

  void _onPasswordChanged(String password) {
    double strength = 0.0;

    if (password.isNotEmpty) {
      if (password.length >= 8) strength += 0.25;
      if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.25;
      if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
      if (RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
        strength += 0.25;
      }
    }

    String label;
    if (strength == 0) {
      label = 'Too weak';
    } else if (strength < 0.5) {
      label = 'Weak';
    } else if (strength < 0.75) {
      label = 'Medium';
    } else {
      label = 'Strong';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordLabel = label;
    });
  }

  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'); // simple email regex
    return emailRegex.hasMatch(email);
  }

  Future<void> addLink() async {
    final name = _addController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a link')),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:5000/links'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      if (res.statusCode == 201) {
        _addController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link added successfully')),
        );
      } else if (res.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link already exists')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add link: ${res.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void goTo(AppView view) {
    setState(() {
      currentView = view;
    });
    if (view == AppView.search) {
      fetchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (currentView) {
      // ---------------- MENU ----------------
      case AppView.menu:
        return Scaffold(
          appBar: AppBar(title: const Text('Choose an option')),
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
                  onTap: () => goTo(AppView.search),
                ),
                _MenuButton(
                  icon: Icons.group_add,
                  label: 'Add Link',
                  onTap: () => goTo(AppView.add),
                ),
                _MenuButton(
                  icon: Icons.category,
                  label: 'Categories',
                  onTap: () => goTo(AppView.categories),
                ),
                _MenuButton(
                  icon: Icons.person_add,
                  label: 'Sign Up or Log In',
                  onTap: () => goTo(AppView.signUpOrLogin),
                ),
              ],
            ),
          ),
        );
      // ---------------- SIGN UP OR LOG IN ----------------
      case AppView.signUpOrLogin:
          return Scaffold(
          appBar: AppBar(title: const Text('Choose an option')),
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
                  onTap: () => goTo(AppView.logIn),
                ),
                _MenuButton(
                  icon: Icons.group_add,
                  label: 'sign up',
                  onTap: () => goTo(AppView.signup),
                ),
             
              ],
            ),
          ),
        );

      // ---------------- SEARCH ----------------
      // קובץ main.dart - בתוך מתודת build, בתוך ה-switch (currentView)

      // ---------------- SEARCH ----------------
      case AppView.search:
        // משתמשים ישירות ב-items כיוון שהסינון מתבצע בשרת
        final filtered = items;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Search links'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => goTo(AppView.menu),
              tooltip: 'Back',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isLoading ? null : fetchItems,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // --- 1. שדה החיפוש (עם Debounce) ---
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                        ),
                        // הוספת ה-Debounce logic כאן:
                        onChanged: (v) {
                          if (_debounce?.isActive ?? false) {
                            _debounce!.cancel();
                          }
                          setState(() => query = v);

                          _debounce = Timer(const Duration(milliseconds: 500), () {
                            // שולח בקשה לשרת רק לאחר שהמשתמש הפסיק להקליד חצי שנייה
                            if (v.isNotEmpty) {
                              fetchItems();
                            } else {
                              // אם התיבה ריקה, נקה את התוצאות
                              setState(() => items = []);
                            }
                          });
                        },
                      ),
                    ),
                    
                    // --- 2. רשימת התוצאות ---
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: fetchItems,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final link = filtered[i]; // זהו אובייקט LinkItem
                            
                            return ListTile(
                              // הכותרת והתיאור
                              title: Text(link.title),
                              subtitle: Text(link.description ?? link.tags ?? link.url),
                              
                              // כפתור פתיחת ה-URL (Link Launcher)
                              trailing: IconButton(
                                icon: const Icon(Icons.link, color: Colors.green),
                                onPressed: () async {
                                  final uri = Uri.parse(link.url);
                                  
                                  // **בדיקה ופתיחת ה-URL**
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cannot open link: ${link.url}'),
                                      ),
                                    );
                                  }
                                },
                              ), // סגירת IconButton
                            ); // סגירת ListTile
                          }, // סגירת itemBuilder
                        ), // סגירת ListView.builder
                      ), // סגירת RefreshIndicator
                    ), // סגירת Expanded
                  ], // סגירת children: []
                ), // סגירת Column
        ); // סגירת Scaffold
      // ---------------- ADD LINK ----------------
      case AppView.add:
        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Link'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => goTo(AppView.menu),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    labelText: 'Link',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: addLink,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Link'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
        );

      // ---------------- CATEGORIES ----------------
      case AppView.categories:
        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => goTo(AppView.menu),
            ),
          ),
          body: const Center(
            child: Text('Categories Page'),
          ),
        );
      // ---------------- LOG IN ----------------
        case AppView.logIn:
        return Scaffold(
          appBar: AppBar(
            title: const Text('log in'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => goTo(AppView.menu),
            ),
          ),
          body: const Center(
            child: Text('Categories Page'),
          ),
        );
      // ---------------- SIGN UP ----------------
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
                userEmail = email;
                goTo(AppView.verifyEmail);
              },
            ),
          ),
        ),
      );

      // ---------------- VERIFY EMAIL ----------------
  case AppView.verifyEmail:
  final email = userEmail ?? 'unknown@email.com';

  final TextEditingController codeController = TextEditingController();

  return Scaffold(
    appBar: AppBar(
      title: const Text('Verify Email'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => goTo(AppView.menu),
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'We sent a verification code to:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Code input
          TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter verification code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();

              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter the code')),
                );
                return;
              }

              // Call backend to verify
              final result = await verifyEmailCode(email, code);

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email verified successfully')),
                  
                );
                goTo(AppView.logIn);
                // TODO: go to next screen, for example:
                // goTo(AppView.menu); or goTo(AppView.home);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message'] ?? 'Invalid or expired code',
                    ),
                  ),
                );
              }
            },
            child: const Text('Verify'),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () async {
              // Optional: button to resend the code
              // await resendVerificationCode(email);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('If this was real, we’d resend the email now')),
              );
            },
            child: const Text('Resend code'),
          ),
        ],
      ),
    ),
  );
    }
  }
}

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


class SignupForm extends StatefulWidget {
  final void Function(String email) onSignupSuccess;

  const SignupForm({
    super.key,
    required this.onSignupSuccess,
  });

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  double _passwordStrength = 0.0;
  String _passwordLabel = 'Too weak';

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

@override
void dispose() {
  usernameController.dispose();
  passwordController.dispose();
  confirmPasswordController.dispose();
  emailController.dispose();
  super.dispose();
}
  // Simple password strength calculation
  void _onPasswordChanged(String password) {
    double strength = 0.0;

    if (password.length >= 6) strength += 0.25;
    if (password.length >= 10) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;

    String label;
    if (strength < 0.25) {
      label = 'Very weak';
    } else if (strength < 0.5) {
      label = 'Weak';
    } else if (strength < 0.75) {
      label = 'Medium';
    } else {
      label = 'Strong';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordLabel = label;
    });
  }

  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$');
    return emailRegex.hasMatch(email);
  }

Future<Map<String, dynamic>> submitCredentials(
    String username, String password, String email) async {
  
  final url = Uri.parse('http://127.0.0.1:5000/signUp');
  // For Android emulator: use http://10.0.2.2:5000/signUp

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'email': email,
      }),
    );

    final body = jsonDecode(response.body);

    return {
      'success': response.statusCode == 200,
      'statusCode': response.statusCode,
      'message': body['message'] ?? body['error'] ?? 'Unknown response'
    };

  } catch (e) {
    return {
      'success': false,
      'statusCode': 0,
      'message': 'Error sending request: $e'
    };
  }
}

  Future<void> _onSubmitPressed(BuildContext context) async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    final email = emailController.text.trim();

    // 1) Empty fields
    if (username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    // 2) Email format
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    // 3) Password strength
    if (_passwordStrength < 0.75) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Password is $_passwordLabel. Please choose a stronger password'),
        ),
      );
      return;
    }

    // 4) Password matching
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // 5) Backend
    final result = await submitCredentials(username, password, email);

    if (result['success'] == true) {
      widget.onSignupSuccess(email);   // <-- send email to parent
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Unexpected error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('Signup screen'),
        const SizedBox(height: 20),

        // Username
        TextField(
          controller: usernameController,
          decoration: const InputDecoration(
            labelText: 'enter user name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // Password with toggle
        TextField(
          controller: passwordController,
          obscureText: !_passwordVisible,
          onChanged: _onPasswordChanged,
          decoration: InputDecoration(
            labelText: 'enter password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _passwordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() => _passwordVisible = !_passwordVisible);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Strength bar
        LinearProgressIndicator(
          value: _passwordStrength,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(
            _passwordStrength < 0.5
                ? Colors.red
                : _passwordStrength < 0.75
                    ? Colors.orange
                    : Colors.green,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Password strength: $_passwordLabel'),
        ),
        const SizedBox(height: 16),

        // Confirm password with toggle
        TextField(
          controller: confirmPasswordController,
          obscureText: !_confirmPasswordVisible,
          decoration: InputDecoration(
            labelText: 'confirm password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Email
        TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'enter email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: () => _onSubmitPressed(context),
          child: const Text("Submit"),
        ),
      ],
    );
  }
}
// בתחתית main.dart
class LinkItem {
  final int id;
  final String url;
  final String title;
  final String? description;
  final String? tags;

  LinkItem({
    required this.id,
    required this.url,
    required this.title,
    this.description,
    this.tags,
  });

  factory LinkItem.fromJson(Map<String, dynamic> json) {
    return LinkItem(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      description: json['description'],
      tags: json['tags'],
    );
  }
}