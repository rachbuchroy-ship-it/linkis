import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; 

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
