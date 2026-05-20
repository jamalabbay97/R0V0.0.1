import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:r0/core/config/app_config_flavors.dart';
import 'package:r0/data/repositories/report_repository_impl.dart';
import 'package:r0/data/services/database_helper.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/firebase_options.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/presentation/providers/auth_provider.dart';
import 'package:r0/presentation/providers/language_provider.dart';
import 'package:r0/presentation/providers/role_provider.dart';
import 'package:r0/presentation/providers/report_access_provider.dart';
import 'package:r0/presentation/providers/theme_provider.dart';
import 'package:r0/presentation/routing/app_router.dart';
import 'package:r0/presentation/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Production builds should provide configuration through --dart-define.
  }
  AppConfig.initialize(AppFlavor.prod);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ReportRepository>(
          create: (_) => ReportRepositoryImpl(DatabaseHelper()),
        ),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, RoleProvider>(
          create: (_) => RoleProvider(),
          update: (_, auth, role) => role!..onAuthStateChanged(auth.user),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ReportAccessProvider>(
          create: (_) => ReportAccessProvider(),
          update: (_, auth, access) => access!..onAuthStateChanged(auth.user),
        ),
      ],
      child: Consumer3<LanguageProvider, ThemeProvider, RoleProvider>(
        builder: (context, languageProvider, themeProvider, roleProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConfig.instance.displayName,
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: themeProvider.themeMode,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('fr')],
            locale: languageProvider.locale,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: AppRouter.appEntry(),
          );
        },
      ),
    );
  }
}
