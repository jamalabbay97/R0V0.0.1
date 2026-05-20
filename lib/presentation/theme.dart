import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF3BAA35);
  static const Color primaryHover = Color(0xFF4BC545);
  static const Color primaryDark = Color(0xFF237E26);
  static const Color secondary = Color(0xFF4BC545);

  static const Color backgroundLight = Color(0xFFF5F7F6);
  static const Color backgroundDark = Color(0xFF0B0F0C);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF121715);
  static const Color cardDark = Color(0xFF161C19);
  static const Color elevatedDark = Color(0xFF1A211D);

  static const Color borderDark = Color(0xFF29332D);
  static const Color borderLight = Color(0xFFDDE5DF);
  static const Color error = Color(0xFFE5484D);
  static const Color warning = Color(0xFFC98A2E);
  static const Color success = Color(0xFF3BAA35);
  static const Color info = Color(0xFF6AA7D8);
  static const Color grey = Color(0xFF7D8781);

  static const Color textPrimary = Color(0xFFF5F7F6);
  static const Color textSecondary = Color(0xFFB7C0BA);
  static const Color textMuted = Color(0xFF7D8781);
  static const Color textDarkPrimary = Color(0xFF111713);
  static const Color textDarkSecondary = Color(0xFF52605A);
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
}

class AppRadii {
  static const double card = 18;
  static const double control = 14;
  static const double input = 14;
  static const double chip = 999;
}

class AppSizes {
  static const double buttonHeight = 52;
  static const double inputHeight = 56;
  static const double navHeight = 64;
  static const double iconBox = 48;
}

class ButtonStyles {
  static ButtonStyle primaryButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.34),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white.withValues(alpha: 0.58),
      fixedSize: const Size.fromHeight(AppSizes.buttonHeight),
      minimumSize: const Size(0, AppSizes.buttonHeight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      elevation: 0,
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  static ButtonStyle secondaryButton(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryHover,
      fixedSize: const Size.fromHeight(AppSizes.buttonHeight),
      minimumSize: const Size(0, AppSizes.buttonHeight),
      side: const BorderSide(color: AppColors.primary, width: 1.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }

  static ButtonStyle ghostButton(BuildContext context) {
    return TextButton.styleFrom(
      foregroundColor: AppColors.primaryHover,
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
    );
  }

  static ButtonStyle dangerButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.error.withValues(alpha: 0.16),
      foregroundColor: const Color(0xFFFFB3B6),
      fixedSize: const Size.fromHeight(AppSizes.buttonHeight),
      minimumSize: const Size(0, AppSizes.buttonHeight),
      side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      elevation: 0,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    error: AppColors.error,
    surface: AppColors.surfaceLight,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textDarkPrimary,
    brightness: Brightness.light,
  );

  return _buildTheme(
    scheme: scheme,
    scaffold: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    card: AppColors.surfaceLight,
    border: AppColors.borderLight,
    onSurface: AppColors.textDarkPrimary,
    onSurfaceSecondary: AppColors.textDarkSecondary,
    isDark: false,
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    error: AppColors.error,
    surface: AppColors.surfaceDark,
    surfaceContainerHigh: AppColors.cardDark,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: AppColors.textPrimary,
    brightness: Brightness.dark,
  );

  return _buildTheme(
    scheme: scheme,
    scaffold: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    card: AppColors.cardDark,
    border: AppColors.borderDark,
    onSurface: AppColors.textPrimary,
    onSurfaceSecondary: AppColors.textSecondary,
    isDark: true,
  );
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required Color scaffold,
  required Color surface,
  required Color card,
  required Color border,
  required Color onSurface,
  required Color onSurfaceSecondary,
  required bool isDark,
}) {
  final divider = border.withValues(alpha: isDark ? 0.72 : 1);

  OutlineInputBorder inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'NotoSans',
    colorScheme: scheme,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: scaffold,
    cardColor: card,
    dividerColor: divider,
    splashColor: AppColors.primary.withValues(alpha: 0.08),
    highlightColor: AppColors.primary.withValues(alpha: 0.05),
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: AppSizes.navHeight,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      iconTheme: IconThemeData(color: onSurface),
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyles.primaryButton(_FakeBuildContext()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyles.secondaryButton(_FakeBuildContext()),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyles.ghostButton(_FakeBuildContext()),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.elevatedDark : Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 17,
      ),
      border: inputBorder(divider),
      enabledBorder: inputBorder(divider),
      focusedBorder: inputBorder(AppColors.primaryHover, width: 1.6),
      errorBorder: inputBorder(AppColors.error),
      focusedErrorBorder: inputBorder(AppColors.error, width: 1.6),
      disabledBorder: inputBorder(divider.withValues(alpha: 0.48)),
      labelStyle: TextStyle(color: onSurfaceSecondary, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryHover,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: onSurfaceSecondary.withValues(alpha: 0.68)),
      helperStyle: TextStyle(color: onSurfaceSecondary),
      errorStyle: const TextStyle(color: AppColors.error),
      suffixIconColor: onSurfaceSecondary,
      prefixIconColor: onSurfaceSecondary,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.elevatedDark : Colors.white,
        border: inputBorder(divider),
        enabledBorder: inputBorder(divider),
        focusedBorder: inputBorder(AppColors.primaryHover, width: 1.6),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: divider),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppColors.elevatedDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: divider),
      ),
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(color: onSurfaceSecondary, fontSize: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.elevatedDark : Colors.white,
      modalBackgroundColor: isDark ? AppColors.elevatedDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: onSurfaceSecondary.withValues(alpha: 0.52),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      disabledColor: onSurfaceSecondary.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      iconColor: onSurfaceSecondary,
      textColor: onSurface,
      titleTextStyle: TextStyle(
        color: onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(color: onSurfaceSecondary, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        AppColors.primary.withValues(alpha: 0.08),
      ),
      dataRowColor: WidgetStatePropertyAll(card),
      dividerThickness: 0.8,
      headingTextStyle: TextStyle(
        color: onSurfaceSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      dataTextStyle: TextStyle(color: onSurface, fontSize: 13),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: onSurface, letterSpacing: 0),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: onSurfaceSecondary,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: onSurfaceSecondary,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onSurfaceSecondary,
        letterSpacing: 0,
      ),
    ),
  );
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
