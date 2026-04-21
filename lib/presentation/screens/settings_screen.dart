import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/presentation/access_control/access_control_definitions.dart';
import 'package:r0/presentation/providers/auth_provider.dart';
import 'package:r0/presentation/providers/language_provider.dart';
import 'package:r0/presentation/providers/report_access_provider.dart';
import 'package:r0/presentation/providers/role_provider.dart';
import 'package:r0/presentation/routing/app_router.dart';
import 'package:r0/presentation/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final roleProvider = context.watch<RoleProvider>();
    final authProvider = context.watch<AuthProvider>();
    final accessProvider = context.watch<ReportAccessProvider>();
    final currentUser = authProvider.user;
    final featureDefinitions = accessProvider.definitions;
    final assignedReports = accessProvider.assignedReportKeys;
    final visibleReports = accessProvider.visibleReportKeys;

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
              const ListTile(
                title: Text('Feature visibility'),
                subtitle: Text(
                  'See every available feature and who can access it.',
                ),
              ),
              ...featureDefinitions.map((definition) {
                final isAssigned = assignedReports.contains(definition.key);
                final isVisible = visibleReports.contains(definition.key);
                final label =
                    AccessControlDefinitions.reportLabels[definition.key] ??
                        definition.key;
                final status = !definition.enabled
                    ? 'Hidden globally by admin'
                    : isVisible
                        ? 'Visible to you'
                        : isAssigned
                            ? 'Assigned but globally hidden'
                            : 'Not assigned to your account';

                return ListTile(
                  leading: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                  ),
                  title: Text(label),
                  subtitle: Text(status),
                );
              }),
              const Divider(),
              if (roleProvider.isAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Admin controls'),
                  subtitle: const Text(
                    'Manage users, feature visibility, and permissions.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRouter.adminUsersRoute,
                  ),
                ),
              if (currentUser != null &&
                  AccessControlDefinitions.isPrimaryProtectedAccount(
                    uid: currentUser.uid,
                    email: currentUser.email,
                  ))
                const ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Primary account protection'),
                  subtitle: Text(
                    'This account is protected and cannot be modified by other admins.',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
