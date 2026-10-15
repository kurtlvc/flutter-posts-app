import 'package:flutter/material.dart';

/// Central place for colors, fonts and component styles so every
/// screen looks consistent.
class AppTheme {
  static const Color primary = Color(0xFF1B7F3B); // university green
  static const Color accent = Color(0xFFF2C230); // university yellow
  static const Color background = Color(0xFFF4F8F4);
  static const Color textDark = Color(0xFF1F2A24);
  static const Color textMuted = Color(0xFF55655B);
  static const Color error = Color(0xFFC62828);

  static const double pagePadding = 16;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 2,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
        bodyMedium: TextStyle(fontSize: 14, color: textMuted, height: 1.4),
        bodyLarge: TextStyle(fontSize: 16, color: textDark, height: 1.5),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: textDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Small reusable banner used to show success / failure / info messages
/// directly on a screen (the exam requires on-screen messages).
class StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onClose;

  const StatusBanner({
    super.key,
    required this.message,
    this.isError = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.error : AppTheme.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close, size: 18, color: color),
            ),
        ],
      ),
    );
  }
}
