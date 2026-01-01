import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart' show ThemeController;
import 'package:linkis/theme_controller.dart';

class MyLinksScreen extends StatefulWidget {
  final int userId;
  final ThemeController themeController; // same controller you use
  const MyLinksScreen({super.key, required this.userId, required this.themeController});

  @override
  State<MyLinksScreen> createState() => _MyLinksScreenState();
}

class _MyLinksScreenState extends State<MyLinksScreen> {
  bool loading = true;
  List<dynamic> links = [];

  // change to your server base
final String baseUrl = "http://44.222.98.94:5000";

  @override
  void initState() {
    super.initState();
    fetchMyLinks();
  }

 Future<void> fetchMyLinks() async {
  setState(() => loading = true);

  final uri = Uri.parse("$baseUrl/my-links?user_id=${widget.userId}");
  final res = await http.get(uri);

  // Debug: see what you're actually getting
  debugPrint("MY-LINKS status: ${res.statusCode}");
  debugPrint("MY-LINKS content-type: ${res.headers['content-type']}");
  debugPrint("MY-LINKS body (first 200): ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}");

  final contentType = (res.headers['content-type'] ?? '').toLowerCase();

  if (!contentType.contains('application/json')) {
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Server returned HTML, not JSON. Check baseUrl/route.")),
    );
    return;
  }

  final data = jsonDecode(res.body);

  if (res.statusCode == 200 && data["ok"] == true) {
    setState(() {
      links = data["results"];
      loading = false;
    });
  } else {
    setState(() => loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(data["message"]?.toString() ?? "Failed to load")),
    );
  }
}

  Future<void> deleteLink(int linkId) async {
    final uri = Uri.parse("$baseUrl/links/$linkId?user_id=${widget.userId}");
    final res = await http.delete(uri);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data["ok"] == true) {
      await fetchMyLinks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deleted")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"]?.toString() ?? "Delete failed")),
      );
    }
  }

  Future<void> openEditDialog(Map<String, dynamic> link) async {
    final titleCtrl = TextEditingController(text: link["title"] ?? "");
    final urlCtrl = TextEditingController(text: link["url"] ?? "");
    final descCtrl = TextEditingController(text: link["description"] ?? "");
    final tagsCtrl = TextEditingController(text: link["tags"] ?? "");

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) {
        final spec = widget.themeController.spec;
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Edit link"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title")),
                const SizedBox(height: 10),
                TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: "URL")),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description")),
                const SizedBox(height: 10),
                TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: "Tags")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final ok = await updateLink(
                  linkId: link["id"],
                  title: titleCtrl.text,
                  url: urlCtrl.text,
                  description: descCtrl.text,
                  tags: tagsCtrl.text,
                );
                Navigator.pop(context, ok);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      await fetchMyLinks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Updated")),
      );
    }
  }
Future<void> confirmDelete(int linkId) async {
  final controller = TextEditingController();
  bool canDelete = false;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Confirm delete"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "This action cannot be undone.\n\n"
                  "Type exactly:\n"
                  "i am sure",
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      canDelete = value.trim() == "i am sure";
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: "i am sure",
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: canDelete
                    ? () => Navigator.pop(context, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text("Delete"),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed == true) {
    await deleteLink(linkId);
  }
}
  Future<bool> updateLink({
    required int linkId,
    required String title,
    required String url,
    required String description,
    required String tags,
  }) async {
    final uri = Uri.parse("$baseUrl/links/$linkId");
    final body = jsonEncode({
      "user_id": widget.userId,
      "title": title,
      "url": url,
      "description": description,
      "tags": tags,
    });

    final res = await http.put(uri, headers: {"Content-Type": "application/json"}, body: body);
    final data = jsonDecode(res.body);

    return res.statusCode == 200 && data["ok"] == true;
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.themeController.spec;

    return Scaffold(
      appBar: AppBar(title: const Text("My Links")),
      body: Container(
        decoration: BoxDecoration(gradient: spec.background),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: fetchMyLinks,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: links.length,
                  itemBuilder: (context, i) {
                    final link = links[i] as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(link["title"] ?? ""),
                        subtitle: Text(link["url"] ?? ""),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => openEditDialog(link),
                            ),
                            IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => confirmDelete(link["id"]),
                            ),

                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
