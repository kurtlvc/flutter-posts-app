import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/favorites_screen.dart';
import 'screens/post_details_screen.dart';
import 'screens/posts_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Part 3: initialize Hive and open the box BEFORE runApp()
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('favoritesBox');

  runApp(const PostReaderApp());
}

class PostReaderApp extends StatelessWidget {
  const PostReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Post Reader & Favorites',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Part 1: three named routes
      initialRoute: '/',
      routes: {
        '/': (context) => const PostsScreen(),
        '/details': (context) => const PostDetailsScreen(),
        '/favorites': (context) => const FavoritesScreen(),
      },
    );
  }
}
