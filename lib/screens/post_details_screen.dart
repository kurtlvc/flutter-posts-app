import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// Route '/details' - shows one post, allows editing it (PUT) and
/// toggles save/unsave (Hive CRUD).
class PostDetailsScreen extends StatefulWidget {
  const PostDetailsScreen({super.key});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  static const String _apiUrl = 'https://jsonplaceholder.typicode.com/posts';

  String? _title;
  String? _body;
  bool _argsLoaded = false;

  void _loadArgsOnce(Map<String, dynamic> args) {
    if (_argsLoaded) return;
    _argsLoaded = true;
    _title = args['title'].toString();
    _body = args['body'].toString();
  }

  Future<void> _editPost(int id, int userId) async {
    final messenger = ScaffoldMessenger.of(context);

    // The dialog owns its controllers and disposes them in its own
    // dispose(), so they are never touched after disposal during the
    // pop transition.
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditPostDialog(
        initialTitle: _title ?? '',
        initialBody: _body ?? '',
      ),
    );

    if (result == null || !mounted) return;
    // Locally created posts (id > 100) don't exist on the fake API,
    // so PUT would fail — update them locally instead.
    if (id > 100) {
      setState(() {
        _title = result['title'];
        _body = result['body'];
      });
      final box = Hive.box('favoritesBox');
      if (box.containsKey(id)) {
        await box.put(id, {
          'id': id,
          'title': _title,
          'body': _body,
          'userId': userId,
        });
      }
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Post updated'),
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 96),
          ),
        );
      return;
    }
    try {
      final response = await http.put(
        Uri.parse('$_apiUrl/$id'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'id': id,
          'title': result['title'],
          'body': result['body'],
          'userId': userId,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _title = result['title'];
          _body = result['body'];
        });
        // keep the saved favorite copy in sync
        final box = Hive.box('favoritesBox');
        if (box.containsKey(id)) {
          await box.put(id, {
            'id': id,
            'title': _title,
            'body': _body,
            'userId': userId,
          });
        }
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Post updated!'),
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.fromLTRB(16, 0, 16, 96),
            ),
          );
      } else {
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to update post. Status code: ${response.statusCode}.'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Failed to update post: $e'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          ),
        );
    }
  }
  Future<void> _toggleFavorite(Map<String, dynamic> args, bool isSaved) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = Hive.box('favoritesBox');
    final int id = args['id'];

    if (isSaved) {
      await box.delete(id);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text('Removed from favorites.'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            action: SnackBarAction(
              label: 'View',
              onPressed: () =>
                  Navigator.pushNamed(context, '/favorites'),
            ),
          ),
        );
    } else {
      // post id is the key, so the same post is never saved twice
      await box.put(id, {
        'id': id,
        'title': args['title'],
        'body': args['body'],
        'userId': args['userId'],
      });
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text('Saved to favorites!'),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            action: SnackBarAction(
              label: 'View',
              onPressed: () =>
                  Navigator.pushNamed(context, '/favorites'),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // retrieve arguments passed through pushNamed (nullable-safe)
    final Object? rawArgs =
        ModalRoute.of(context)?.settings.arguments;
    if (rawArgs == null || rawArgs is! Map) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Post Details'),
        ),
        body: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(AppTheme.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No post data was passed to this screen.\n'
                  'Open a post from the Posts list.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final args = Map<String, dynamic>.from(rawArgs);
    if (args['id'] == null ||
        args['title'] == null ||
        args['body'] == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Incomplete post data.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }
    final int postId = (args['id'] as num).toInt();
    args['id'] = postId;
    final int userId = (args['userId'] as num?)?.toInt() ?? 1;
    args['userId'] = userId;
    _loadArgsOnce(args);
    final String title = _title ?? args['title'].toString();
    final String body = _body ?? args['body'].toString();

    return ValueListenableBuilder<Box>(
      valueListenable: Hive.box('favoritesBox').listenable(),
      builder: (context, box, _) {
        final bool isSaved = box.containsKey(args['id']);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              // hand the (possibly edited) post back to the list
              onPressed: () => Navigator.pop(context, {
                'id': postId,
                'title': title,
                'body': body,
                'userId': userId,
              }),
            ),
            title: const Text('Post Details'),
            actions: [
              IconButton(
                tooltip: 'Edit post',
                icon: const Icon(Icons.edit),
                onPressed: () => _editPost(postId, userId),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(AppTheme.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Single content card with header layout inside
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Header layout INSIDE the card:
                              // avatar + title meta + status chip
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      '${args['id']}',
                                      style: const TextStyle(
                                          fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Post #${args['id']}',
                                          style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '@user$userId',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSaved
                                          ? Colors.green.shade50
                                          : Colors.grey.shade200,
                                      borderRadius:
                                          BorderRadius.circular(
                                              20),
                                      border: Border.all(
                                        color: isSaved
                                            ? Colors.green.shade200
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSaved
                                              ? Icons.favorite
                                              : Icons
                                                  .favorite_border,
                                          size: 14,
                                          color: isSaved
                                              ? Colors.green.shade800
                                              : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isSaved
                                              ? 'Saved'
                                              : 'Not saved',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: isSaved
                                                ? Colors.green
                                                    .shade800
                                                : AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const Divider(height: 28),
                              Text(
                                body,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom action bar
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    0,
                    AppTheme.pagePadding,
                    AppTheme.pagePadding,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, {
                                'id': postId,
                                'title': title,
                                'body': body,
                                'userId': userId,
                              }),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 14),
                            foregroundColor:
                                AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: isSaved
                            ? OutlinedButton.icon(
                                onPressed: () =>
                                    _toggleFavorite(
                                        {
                                          'id': postId,
                                          'title': title,
                                          'body': body,
                                          'userId': userId,
                                        },
                                        true),
                                icon: const Icon(
                                  Icons.favorite,
                                  color: AppTheme.error,
                                ),
                                label: const Text('Unsave'),
                                style:
                                    OutlinedButton.styleFrom(
                                  padding: const EdgeInsets
                                      .symmetric(
                                          vertical: 14),
                                  foregroundColor:
                                      AppTheme.error,
                                  side: const BorderSide(
                                    color: AppTheme.error,
                                  ),
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                  ),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () =>
                                    _toggleFavorite(
                                        {
                                          'id': postId,
                                          'title': title,
                                          'body': body,
                                          'userId': userId,
                                        },
                                        false),
                                icon: const Icon(Icons
                                    .favorite_border),
                                label: const Text(
                                    'Save to Favorites'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Edit dialog that owns its [TextEditingController]s and disposes them
/// in [State.dispose], so the framework never touches a disposed
/// controller during the pop transition.
class _EditPostDialog extends StatefulWidget {
  final String initialTitle;
  final String initialBody;

  const _EditPostDialog({
    required this.initialTitle,
    required this.initialBody,
  });

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialTitle);
  late final TextEditingController _bodyController =
      TextEditingController(text: widget.initialBody);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Post'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Title cannot be empty'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Body'),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'title': _titleController.text.trim(),
                'body': _bodyController.text.trim(),
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
