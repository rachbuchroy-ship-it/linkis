import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class LoginForm extends StatefulWidget {
  final void Function(int userId, String email, String username) onLoginSuccess;

  const LoginForm({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _passwordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _login(String email, String password) async {
    final url = Uri.parse('http://127.0.0.1:5000/login');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(res.body);

      return {
        'success': body['success'] == true,
        'statusCode': res.statusCode,
        'message': body['message'] ?? body['error'] ?? 'Unknown response',
        'user_id': body['user_id'],
        'username': body['username'],
        'email': body['email'],
      };
    } catch (e) {
      return {
        'success': false,
        'statusCode': 0,
        'message': 'Error sending request: $e',
        'user_id': null,
        'username': null,
        'email': null,
      };
    }
  }

Future<Map<String, dynamic>> _requestPasswordResetLink(String email) async {
  final url = Uri.parse('http://127.0.0.1:5000/requestPasswordReset');

  try {
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final body = jsonDecode(res.body);
    return {
      'success': body['success'] == true,
      'message': body['message'] ?? body['error'] ?? 'Done',
      'statusCode': res.statusCode,
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'Error: $e',
      'statusCode': 0,
    };
  }
}

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController forgotEmailController =
        TextEditingController(text: emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Forgot password'),
          content: TextField(
            controller: forgotEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(forgotEmailController.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    final result = await _requestPasswordResetLink(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? 'Done')),
    );
  }

  Future<void> _onLoginPressed() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in successfully')),
      );

      final userId = result['user_id'] as int;
      final userEmail = result['email'] as String;
      final username = result['username'] as String;

      widget.onLoginSuccess(userId, userEmail, username);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Log in',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),

        TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        TextField(
          controller: passwordController,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
            ),
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _showForgotPasswordDialog,
            child: const Text('Forgot password?'),
          ),
        ),

        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: _isLoading ? null : _onLoginPressed,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Log in'),
        ),
      ],
    );
  }
}