import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'Config.dart';

/// Change this depending on platform:
/// - Web / Desktop: "http://127.0.0.1:5000"
/// - Android emulator: "http://10.0.2.2:5000"

class AddLinkForm extends StatefulWidget {
  final int? loggedInUserId;

  const AddLinkForm({
    super.key,
    required this.loggedInUserId,
  });

  @override
  State<AddLinkForm> createState() => _AddLinkFormState();
}

class _AddLinkFormState extends State<AddLinkForm> {
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _addLink() async {
    final url = _urlController.text.trim();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final tags = _tagsController.text.trim();
    
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a link')),
      );
      return;
    }
    if ( title.isEmpty ) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }    if (description.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter more then 20 letters in description')),
      );
      return;
    }
    if (widget.loggedInUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to add a link')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await http.post(
        Uri.http(IP_PORT, '/links'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'title': title.isEmpty ? url : title,
          'description': description,
          'tags': tags,
          'user_id': widget.loggedInUserId,
        }),
      );

      setState(() => _isSubmitting = false);

      if (res.statusCode == 201) {
        _urlController.clear();
        _titleController.clear();
        _descriptionController.clear();
        _tagsController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link added successfully')),
        );
      } else {
        String message;
        try {
          final body = jsonDecode(res.body);
          message = body['error']?.toString() ??
              body['message']?.toString() ??
              res.body;
        } catch (_) {
          message = res.body;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add link: $message')),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // URL
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Link (URL)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (atleast 20 letters)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Tags
              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (optional, e.g. "work, flutter, docs")',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _addLink,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(_isSubmitting ? 'Adding...' : 'Add Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}