import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/providers/language_provider.dart';
import 'package:r0/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    runApp(const MyApp());
  } catch (e, stack) {
    debugPrint('Error during initialization: $e');
    debugPrint(stack.toString());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'R0',
            theme: ThemeData(
              primarySwatch: Colors.green,
              primaryColor: Colors.green[700],
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.green[700]!,
                primary: Colors.green[700]!,
                secondary: Colors.green[800]!,
                onPrimary: Colors.white,
                onSecondary: Colors.white,
                surface: Colors.white,
                error: Colors.red,
                onError: Colors.white,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // English
              Locale('fr'), // French
            ],
            locale: languageProvider.locale,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
} 