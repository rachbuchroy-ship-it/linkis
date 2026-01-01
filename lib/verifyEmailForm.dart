import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
/// ---------------- VERIFY EMAIL FORM ----------------

class VerifyEmailForm extends StatefulWidget {
  final String email;
  final VoidCallback onBack;
  final VoidCallback onVerified;

  const VerifyEmailForm({
    super.key,
    required this.email,
    required this.onBack,
    required this.onVerified,
  });

  @override
  State<VerifyEmailForm> createState() => _VerifyEmailFormState();
}

class _VerifyEmailFormState extends State<VerifyEmailForm> {
  final TextEditingController _codeController = TextEditingController();
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resendVerificationCode() async {
    final url = Uri.parse('http://44.222.98.94:5000/resendVerificationCode');
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': widget.email}),
    );
  }

  Future<Map<String, dynamic>> _verifyEmailCode(
      String email, String code) async {
    final url = Uri.parse('http://44.222.98.94:5000/verify');

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

  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendCooldown--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
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
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter verification code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final code = _codeController.text.trim();

                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter the code')),
                  );
                  return;
                }

                final result = await _verifyEmailCode(email, code);

                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email verified successfully'),
                    ),
                  );
                  widget.onVerified();
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
              onPressed: _resendCooldown == 0
                  ? () async {
                      await _resendVerificationCode();
                      _startResendCooldown();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code sent')),
                      );
                    }
                  : null,
              child: Text(
                _resendCooldown == 0
                    ? "Resend code"
                    : "Wait $_resendCooldown s",
              ),
            )
          ],
        ),
      ),
    );
  }
}