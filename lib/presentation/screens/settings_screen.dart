import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/presentation/providers/language_provider.dart';
import 'package:r0/presentation/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton<Locale>(
                  value: languageProvider.locale,
                  underline: Container(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                      value: const Locale('en'),
                      child: Text(AppLocalizations.of(context)!.english),
                    ),
                    DropdownMenuItem(
                      value: const Locale('fr'),
                      child: Text(AppLocalizations.of(context)!.french),
                    ),
                  ],
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      languageProvider.setLocale(newLocale);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: Text(AppLocalizations.of(context)!.darkMode),
                trailing: Switch(
                  value: Provider.of<ThemeProvider>(context).themeMode ==
                      ThemeMode.dark,
                  onChanged: (value) {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .toggleTheme(value);
                  },
                ),
              ),
              const Divider(),
              // Add more settings here as needed
            ],
          ),
        ),
      ),
    );
  }
}
