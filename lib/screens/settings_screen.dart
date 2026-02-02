import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/providers/language_provider.dart';
import 'package:r0/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.language),
            trailing: DropdownButton<Locale>(
              value: languageProvider.locale,
              underline: Container(),
              isDense: true,
              items: [
                DropdownMenuItem(
                  value: const Locale('en'),
                  child: Text(l10n.english),
                ),
                DropdownMenuItem(
                  value: const Locale('fr'),
                  child: Text(l10n.french),
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
            title: Text(l10n.darkMode),
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
    );
  }
}
