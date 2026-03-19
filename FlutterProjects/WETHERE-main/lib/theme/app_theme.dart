import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryDark = Color(0xFF001F54); // Navy blue
  static const Color primaryLight = Color(0xFF4CAF50); // Green accent
  static const Color accentOrange = Color(0xFFFF6B35); // Orange-red
  static const Color backgroundColor = Colors.white; // Keep for reference, but prefer Theme.of(context)
  static const Color textPrimary = Colors.black; // Keep for reference
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFFAAAAAA);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color dividerColor = Color(0xFFF0F0F0);

  // TextStyles - Removed hardcoded colors to allow theme-based colors
  static const TextStyle headlineXL = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingL = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingM = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingS = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // Spacing
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 16;
  static const double spacingLg = 24;
  static const double spacingXl = 32;
  static const double spacingXxl = 40;

  // Border radius
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
  static const double radiusMax = 28;

  // Input field styling
  static InputDecoration buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    // Note: This won't have access to context here, so it's better used 
    // where context is available, but we can make it more neutral.
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: textHint, fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingMd,
      ),
    );
  }

  // Button styling - Orange Primary with enhanced hover
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accentOrange,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMax),
    ),
    padding: const EdgeInsets.symmetric(vertical: spacingMd),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return Colors.white.withOpacity(0.15);
      }
      if (states.contains(WidgetState.pressed)) {
        return Colors.white.withOpacity(0.25);
      }
      return null;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return accentOrangeDark; // Darker on hover
      }
      if (states.contains(WidgetState.disabled)) {
        return borderColor;
      }
      return accentOrange;
    }),
  );

  // Navy Secondary Button with enhanced hover
  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryDark,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMax),
    ),
    padding: const EdgeInsets.symmetric(vertical: spacingMd),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return Colors.white.withOpacity(0.15);
      }
      return null;
    }),
  );

  // Text button style with visible hover
  static ButtonStyle textButtonStyle = TextButton.styleFrom(
    foregroundColor: accentOrange,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return accentOrange.withOpacity(0.1);
      }
      return null;
    }),
  );

  // Hover colors
  static Color get accentOrangeLight => accentOrange.withOpacity(0.8);
  static const Color accentOrangeDark = Color(0xFFE55A2B); // Darker orange for hover

  // New: Proper ThemeData for Light Mode
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMax)),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentOrange,
        brightness: Brightness.light,
        primary: primaryDark,
        secondary: primaryLight,
        tertiary: accentOrange,
        surface: Colors.white,
        onSurface: Colors.black,
        onSurfaceVariant: textSecondary,
      ),
    );
  }

  // New: Proper ThemeData for Dark Mode
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF334155)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMax)),
        ),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentOrange,
        brightness: Brightness.dark,
        primary: accentOrange,
        secondary: primaryLight,
        surface: const Color(0xFF1E293B),
        onSurface: Colors.white,
        onSurfaceVariant: const Color(0xFF94A3B8),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}
}
