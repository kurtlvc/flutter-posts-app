import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../theme/app_theme.dart';

/// Route '/favorites' - Hive Read and Delete.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Box _box = Hive.box('favoritesBox');

  // ---------- DELETE ----------
  Future<void> _delete(Map post, {bool confirm = false}) async {
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove favorite?'),
          content: Text(
            '"${post['title']}" will be removed from favorites.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
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
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final backup = Map<dynamic, dynamic>.from(post);
    await _box.delete(post['id']);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Removed from favorites.'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _box.put(backup['id'], backup),
        ),
      ),
    );
  }

  // ---------- READ ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: ValueListenableBuilder(
              valueListenable: _box.listenable(),
              builder: (context, Box box, _) {
                final favorites = box.values.toList();

                if (favorites.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border,
                            size: 64, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                            'No favorites yet.\nTap Save on any post to keep it here.',
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final post = Map<dynamic, dynamic>.from(favorites[index]);

                    return Dismissible(
                      key: ValueKey(post['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.only(right: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: AppTheme.error,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(post),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/details',
                              arguments: {
                                'id': post['id'],
                                'title': post['title'],
                                'body': post['body'],
                                'userId': post['userId'],
                              },
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    child: Text(
                                      '${post['id']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (post['userId'] != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    bottom: 2),
                                            child: Text(
                                              '@user${post['userId']}',
                                              maxLines: 1,
                                              overflow: TextOverflow
                                                  .ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color:
                                                    AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          post['title'],
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          post['body'],
                                          maxLines: 2,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _delete(post,
                                        confirm: true),
                                    icon: const Icon(
                                        Icons.favorite,
                                        size: 16),
                                    label:
                                        const Text('Unsave'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          AppTheme.error,
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
