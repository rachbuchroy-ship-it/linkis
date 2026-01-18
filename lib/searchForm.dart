import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'Config.dart';

class SearchForm extends StatefulWidget {
  const SearchForm({super.key, this.userId}); // 👈 nullable
  final int? userId;

  @override
  State<SearchForm> createState() => _SearchFormState();
}

class _SearchFormState extends State<SearchForm> {
  final TextEditingController linkSearchName = TextEditingController();
  int? get currentUserId => widget.userId; // 👈 nullable
  bool get isGuest => currentUserId == null;

  bool isLoading = false;
  String? errorMessage;
  List<dynamic> searchResults = [];


  @override
  void dispose() {
    linkSearchName.dispose();
    super.dispose();
  }

  String _formatIsoDate(dynamic iso) {
    final s = (iso ?? '').toString().trim();
    if (s.isEmpty) return '(unknown time)';

    try {
      final dt = DateTime.parse(s).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return s;
    }
  }

  String _ensureScheme(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;
    return (raw.startsWith('http://') || raw.startsWith('https://'))
        ? raw
        : 'https://$raw';
  }

  Future<void> _openUrl(String url) async {
    final withScheme = _ensureScheme(url);
    if (withScheme.isEmpty) return;

    final uri = Uri.tryParse(withScheme);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _copyToClipboard(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  Future<void> _shareAllPlatforms(String title, String url) async {
    final fixed = _ensureScheme(url);
    if (fixed.isEmpty) return;

    final t = title.trim();

    // ✅ ad text (edit freely)
    const ad = '\n\n—\nSaved with Linkis • Try it too';

    final text = (t.isEmpty ? fixed : '$t\n$fixed') + ad;

    await Share.share(
      text,
      subject: t.isEmpty ? 'Link' : t,
    );
  }

Future<void> _shareToWhatsApp(String title, String url) async {
  final fixed = _ensureScheme(url);
  if (fixed.isEmpty) return;

  final t = title.trim();

  const ad = '\n\n—\nSaved with Linkiz • Try it too';
  final text = (t.isEmpty ? fixed : '$t\n$fixed') + ad;

  final encoded = Uri.encodeComponent(text);
  final wa = Uri.parse('https://wa.me/?text=$encoded');

  final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
  if (!ok && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not share to WhatsApp')),
    );
  }
}

  Future<void> _onSearch() async {
    final query = linkSearchName.text.trim();

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        errorMessage = null;
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final params = <String, String>{'query': query};

      if (currentUserId != null) {
        params['user_id'] = currentUserId.toString();
      }

      final url = Uri.http(
        IP_PORT,
        '/search',
        params,
      );


      final res = await http.get(url);
      print('SEARCH URL: $url');
      print('STATUS: ${res.statusCode}');
      print('BODY: ${res.body}');
      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);

        final List<dynamic> results =
            (decoded is Map<String, dynamic> && decoded['results'] is List)
                ? List<dynamic>.from(decoded['results'] as List)
                : <dynamic>[];

        results.sort((a, b) {
          final likesA =
              int.tryParse((a['likes_count'] ?? 0).toString()) ?? 0;
          final likesB =
              int.tryParse((b['likes_count'] ?? 0).toString()) ?? 0;
          return likesB.compareTo(likesA); // more likes first
        });

        setState(() {
          searchResults = results;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          isLoading = false;
          searchResults = [];
          errorMessage = 'Search failed (HTTP ${res.statusCode})';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        searchResults = [];
        errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _toggleLike(int linkId, int index) async {
    final current = Map<String, dynamic>.from(searchResults[index] as Map);

    final bool oldLiked = current['liked_by_me'] == true;
    final int oldCount =
        int.tryParse((current['likes_count'] ?? 0).toString()) ?? 0;

    // optimistic update
    final bool newLiked = !oldLiked;
    final int newCount = newLiked ? (oldCount + 1) : (oldCount > 0 ? oldCount - 1 : 0);

    setState(() {
      current['liked_by_me'] = newLiked;
      current['likes_count'] = newCount;
      searchResults[index] = current;
    });

    try {
      final url = Uri.http(
        IP_PORT,
        '/links/$linkId/toggleLike',
      );
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': currentUserId}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        setState(() {
          current['liked_by_me'] = decoded['liked'] == true;
          current['likes_count'] =
              int.tryParse((decoded['likes_count'] ?? 0).toString()) ?? 0;
          searchResults[index] = current;
        });
      } else {
        // rollback
        setState(() {
          current['liked_by_me'] = oldLiked;
          current['likes_count'] = oldCount;
          searchResults[index] = current;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Like failed (HTTP ${res.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // rollback
      setState(() {
        current['liked_by_me'] = oldLiked;
        current['likes_count'] = oldCount;
        searchResults[index] = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Like error: $e')),
      );
    }
  }

  void _showLinkDetails(Map map) {
    final title = (map['title'] ?? '').toString();
    final url = (map['url'] ?? '').toString();
    final description = (map['description'] ?? '').toString();
    final tags = (map['tags'] ?? '').toString();

    final creator = (map['creator_username'] ?? '').toString();
    final createdAt = _formatIsoDate(map['created_at']);
    final likesCount = int.tryParse((map['likes_count'] ?? 0).toString()) ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title.trim().isEmpty ? 'Link details' : title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Created by:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(creator.trim().isEmpty ? '(unknown)' : creator),

                const SizedBox(height: 16),
                const Text('Created at:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(createdAt),

                const SizedBox(height: 16),
                const Text('Likes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$likesCount'),

                const SizedBox(height: 16),
                const Text('URL:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: url.trim().isEmpty ? null : () => _openUrl(url),
                  child: Text(
                    url.trim().isEmpty ? '(no url)' : _ensureScheme(url),
                    style: TextStyle(
                      color: url.trim().isEmpty ? null : Colors.blue,
                      decoration:
                          url.trim().isEmpty ? TextDecoration.none : TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(description.trim().isEmpty ? '(no description)' : description),

                const SizedBox(height: 16),
                const Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText(tags.trim().isEmpty ? '(no tags)' : tags),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  url.trim().isEmpty ? null : () => _copyToClipboard(_ensureScheme(url)),
              child: const Text('Copy link'),
            ),
            TextButton(
              onPressed: url.trim().isEmpty ? null : () => _shareToWhatsApp(title, url),
              child: const Text('WhatsApp'),
            ),
            TextButton(
              onPressed: url.trim().isEmpty ? null : () => _shareAllPlatforms(title, url),
              child: const Text('More...'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showNoResults = !isLoading && errorMessage == null && searchResults.isEmpty;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: linkSearchName,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
              decoration: InputDecoration(
                labelText: 'Search',
                hintText: 'Type a name...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _onSearch,
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (isLoading) const LinearProgressIndicator(),

            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 8),

            Expanded(
              child: showNoResults
                  ? const Center(child: Text('No results'))
                  : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final item = searchResults[index];
                        final map = (item is Map) ? item : const {};

                        final title = (map['title'] ?? '').toString();
                        final url = (map['url'] ?? '').toString();
                        final creator = (map['creator_username'] ?? '').toString().trim();
                        final createdAt = _formatIsoDate(map['created_at']);

                        final likesCount =
                            int.tryParse((map['likes_count'] ?? 0).toString()) ?? 0;
                        final likedByMe = map['liked_by_me'] == true;
                        final semanticScore = (map['semantic_score'] is num)
                            ? (map['semantic_score'] as num).toDouble()
                            : double.tryParse((map['semantic_score'] ?? '').toString());

                        final ftsRank = (map['rank'] is num)
                            ? (map['rank'] as num).toDouble()
                            : double.tryParse((map['rank'] ?? '').toString());

                        final idRaw = map['id'];
                        final linkId =
                            (idRaw is int) ? idRaw : int.tryParse('$idRaw') ?? 0;

                        return Card(
                          child: ListTile(
                            title: Text(title.trim().isEmpty ? '(no title)' : title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: url.trim().isEmpty ? null : () => _openUrl(url),
                                  child: Text(
                                    url.trim().isEmpty ? '(no url)' : _ensureScheme(url),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: url.trim().isEmpty ? null : Colors.blue,
                                      decoration: url.trim().isEmpty
                                          ? TextDecoration.none
                                          : TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'By: ${creator.isEmpty ? '(unknown)' : creator} • $createdAt',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'semantic: ${semanticScore?.toStringAsFixed(3) ?? '-'} • fts: ${ftsRank?.toStringAsFixed(3) ?? '-'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            isThreeLine: true,

                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$likesCount'),
                                IconButton(
                                  icon: Icon(
                                    likedByMe ? Icons.favorite : Icons.favorite_border,
                                    color: likedByMe ? Colors.red : null,
                                  ),
                                    onPressed: (isGuest || linkId == 0) ? null : () => _toggleLike(linkId, index),
                                ),
                              ],
                            ),

                            onTap: () => _showLinkDetails(Map.from(map)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}