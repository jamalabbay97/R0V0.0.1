import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:r0/presentation/providers/language_provider.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/presentation/theme.dart';
import 'package:r0/domain/models/report.dart';

/// Helper function to create a test app with necessary providers
Widget createTestApp({
  required Widget child,
  LanguageProvider? languageProvider,
}) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => languageProvider ?? LanguageProvider(),
    child: Consumer<LanguageProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          theme: buildLightTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('fr'),
          ],
          locale: provider.locale,
          home: child,
        );
      },
    ),
  );
}

/// Helper to wait for async operations in tests
Future<void> waitForAsync() async {
  await Future.delayed(const Duration(milliseconds: 100));
}

/// Helper to create a mock report for testing
Report createMockReport({
  int? id,
  String? description,
  DateTime? date,
  String? group,
  String? type,
  Map<String, dynamic>? additionalData,
}) {
  return Report(
    id: id,
    description: description ?? 'Test Report',
    date: date ?? DateTime.now(),
    group: group ?? 'R0',
    type: type ?? 'Activity',
    additionalData: additionalData,
  );
}
