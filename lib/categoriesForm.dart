import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';


/// ---------------- CATEGORIES FORM ----------------

class CategoriesForm extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const CategoriesForm({
    super.key,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
      ),
      body: const Center(
        child: Text('Categories Page'),
      ),
    );
  }
}