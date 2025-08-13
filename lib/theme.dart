import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2E7D32); // close to Colors.green[700]
  static const Color primaryDark = Color(0xFF1B5E20); // close to Colors.green[900]
  static const Color error = Color(0xFFD32F2F); // Material Design error color
  static const Color warning = Color(0xFFF57C00); // Material Design warning color
  static const Color success = Color(0xFF388E3C); // Material Design success color
}

class ButtonStyles {
  static ButtonStyle primaryButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 2,
    );
  }

  static ButtonStyle secondaryButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Theme.of(context).colorScheme.onSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 2,
    );
  }

  static ButtonStyle errorButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.error,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 2,
    );
  }

  static ButtonStyle successButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 2,
    );
  }

  static ButtonStyle outlinedPrimaryButton(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      side: BorderSide(color: Theme.of(context).colorScheme.primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    );
  }

  static ButtonStyle outlinedSecondaryButton(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.secondary,
      side: BorderSide(color: Theme.of(context).colorScheme.secondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    );
  }

  static ButtonStyle textPrimaryButton(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    );
  }
}

ThemeData buildLightTheme() {
  const Color primary = AppColors.primary;
  const Color primaryDark = AppColors.primaryDark;

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    secondary: primaryDark,
    error: AppColors.error,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    colorScheme: scheme,
    primaryColor: primary,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.primary.withValues(alpha: 0.38),
        disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      surfaceTintColor: Colors.white,
    ),
  );
}


