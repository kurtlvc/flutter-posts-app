import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// Route '/' - lists posts from JSONPlaceholder (Part 2).
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});

  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  static const String _apiUrl = 'https://jsonplaceholder.typicode.com/posts';

  List<dynamic> _posts = [];
  bool _isLoading = true;
  String? _errorMessage; // shown when GET fails with an empty list

  @override
  void initState() {
    super.initState();
    fetchPosts(); // async method called from initState()
  }

  // ---------- GET ----------
  // First load shows a fullscreen spinner; refreshes keep the old list
  // visible and report failures via SnackBar instead of wiping the list.
  Future<void> fetchPosts() async {
    final bool isRefresh = _posts.isNotEmpty;
    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _posts = jsonDecode(response.body);
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        if (isRefresh) {
          _showRefreshError(
              'Refresh failed with status: ${response.statusCode}.');
        } else {
          setState(() {
            _errorMessage =
                'Request failed with status: ${response.statusCode}.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (isRefresh) {
        _showRefreshError('Refresh failed: $e');
      } else {
        setState(() {
          _errorMessage = 'Something went wrong: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showRefreshError(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ---------- POST ----------
  // Returns true when the API accepted the post.
  Future<bool> createPost(String title, String body) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'title': title, 'body': body, 'userId': 1}),
      );
      if (!mounted) return false;

      if (response.statusCode == 201) {
        final created = jsonDecode(response.body);
        setState(() {
          _posts.insert(0, created);
        });
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Post created successfully!'),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return true;
      } else {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to create post. Status code: ${response.statusCode}.'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return false;
    }
  }

  // ---------- DELETE ----------
  Future<void> _deletePost(dynamic id, {bool confirm = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete post?'),
          content: const Text(
              'This will delete the post. Are you sure you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    // Locally created posts (id > 100) don't exist on the fake API,
    // so DELETE would fail — remove them locally instead.
    if ((id as num).toInt() > 100) {
      setState(() => _posts.removeWhere((p) => p['id'] == id));
      Hive.box('favoritesBox').delete(id);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Post deleted locally.'),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    try {
      final response = await http.delete(Uri.parse('$_apiUrl/$id'));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() => _posts.removeWhere((p) => p['id'] == id));
        Hive.box('favoritesBox').delete(id);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Post deleted.'),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
      } else {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to delete post. Status code: ${response.statusCode}.'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to delete post: $e'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  // ---------- Dialog (title + body, neither may be empty) ----------
  Future<void> _openAddDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('New Post'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        enabled: !isSending,
                        decoration:
                            const InputDecoration(labelText: 'Title'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Title cannot be empty'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: bodyController,
                        enabled: !isSending,
                        maxLines: 4,
                        decoration:
                            const InputDecoration(labelText: 'Body'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Body cannot be empty'
                                : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!
                              .validate()) {
                            return;
                          }
                          setDialogState(
                              () => isSending = true);
                          await createPost(
                            titleController.text.trim(),
                            bodyController.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts Reader'),
        actions: [
          IconButton(
            tooltip: 'Favorites',
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.pushNamed(context, '/favorites'),
          ),
        ],
      ),
      body: _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        tooltip: 'Add post',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 56, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.error)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: fetchPosts,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // CRUD visibility: the list itself listens to favoritesBox so each
    // card shows a live Save/Unsave (Create/Delete) action inline.
    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box('favoritesBox').listenable(),
      builder: (context, favBox, _) {
        return RefreshIndicator(
      onRefresh: fetchPosts,
      child: ListView.builder(
      padding: const EdgeInsets.all(AppTheme.pagePadding),
      itemCount: _posts.length,
      itemBuilder: (itemContext, index) {
        final post = _posts[index];
        final bool isFav = favBox.containsKey(post['id']);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              // pass id, title, body and userId as arguments
              final updated = await Navigator.pushNamed(
                context,
                '/details',
                arguments: {
                  'id': post['id'],
                  'title': post['title'],
                  'body': post['body'],
                  'userId': post['userId'],
                },
              );
              // merge back any edit made on the details screen
              if (updated is Map && updated['id'] != null && mounted) {
                setState(() {
                  final i = _posts.indexWhere(
                      (p) => p['id'] == updated['id']);
                  if (i != -1) {
                    _posts[i] = {
                      ..._posts[i] as Map,
                      'title': updated['title'] ?? _posts[i]['title'],
                      'body': updated['body'] ?? _posts[i]['body'],
                    };
                  }
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        child: Text(
                          '${post['id']}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@user${post['userId']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              post['title'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post['body'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Bottom action bar: full-size touch targets
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: isFav
                              ? 'Unsave'
                              : 'Save to favorites',
                          child: TextButton.icon(
                          icon: Icon(
                            isFav
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 20,
                            color: isFav
                                ? AppTheme.error
                                : AppTheme.primary,
                          ),
                          label: Text(
                            isFav ? 'Unsave' : 'Save',
                            style: TextStyle(
                              color: isFav
                                  ? AppTheme.error
                                  : AppTheme.primary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            if (isFav) {
                              await favBox
                                  .delete(post['id']);
                            } else {
                              await favBox.put(post['id'], {
                                'id': post['id'],
                                'title': post['title'],
                                'body': post['body'],
                                'userId': post['userId'],
                              });
                            }
                            if (!itemContext.mounted) return;
                            final itemMessenger =
                                ScaffoldMessenger.of(itemContext);
                            itemMessenger.clearSnackBars();
                            itemMessenger.showSnackBar(
                              SnackBar(
                                content: Text(isFav
                                    ? 'Removed from favorites.'
                                    : 'Saved to favorites!'),
                                duration: const Duration(
                                    seconds: 4),
                                behavior:
                                    SnackBarBehavior.floating,
                              ),
                            );
                          },
                          ),
                          ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: 'Delete post',
                          child: TextButton.icon(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: AppTheme.error,
                          ),
                          label: const Text(
                            'Delete',
                            style: TextStyle(
                                color: AppTheme.error),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _deletePost(post['id'], confirm: true),
                        ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
      },
    );
  }
}
